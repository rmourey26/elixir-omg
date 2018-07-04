defmodule OmiseGOWatcher.BlockGetterTest do
  use ExUnitFixtures
  use ExUnit.Case, async: false
  use OmiseGO.API.Fixtures
  use Plug.Test

  alias OmiseGO.API
  alias OmiseGO.API.Block
  alias OmiseGO.Eth
  alias OmiseGO.JSONRPC.Client
  alias OmiseGOWatcher.BlockGetter
  alias OmiseGOWatcher.TestHelper

  @moduletag :integration

  @timeout 20_000
  @block_offset 1_000_000_000
  @eth OmiseGO.API.Crypto.zero_address()

  defp deposit_to_child_chain(to, value, contract) do
    {:ok, destiny_enc} = Eth.DevHelpers.import_unlock_fund(to)
    Eth.DevHelpers.deposit(value, 0, destiny_enc, contract.contract_addr)
  end

  defp wait_for_deposit({:ok, deposit_tx_hash}, contract) do
    {:ok, receipt} = Eth.WaitFor.eth_receipt(deposit_tx_hash)
    deposit_blknum = Eth.DevHelpers.deposit_blknum_from_receipt(receipt)

    post_deposit_child_block =
      deposit_blknum - 1 +
        (Application.get_env(:omisego_api, :ethereum_event_block_finality_margin) + 1) *
          Application.get_env(:omisego_eth, :child_block_interval)

    {:ok, _} =
      Eth.DevHelpers.wait_for_current_child_block(post_deposit_child_block, true, 60_000, contract.contract_addr)

    deposit_blknum
  end

  defp wait_for_BlockGetter_get_block(block_number) do
    fn ->
      Eth.WaitFor.repeat_until_ok(fn ->
        # TODO use event system
        case GenServer.call(BlockGetter, :get_height, 10_000) < block_number do
          true -> :repeat
          false -> {:ok, block_number}
        end
      end)
    end
    |> Task.async()
    |> Task.await(@timeout)
  end

  @tag fixtures: [:watcher_sandbox, :contract, :geth, :child_chain, :root_chain_contract_config, :alice, :bob]
  test "get the blocks from child chain after transaction and start exit",
       %{contract: contract, alice: alice, bob: bob} do
    deposit_blknum = alice |> deposit_to_child_chain(10, contract) |> wait_for_deposit(contract)
    # TODO remove slpeep after synch deposit synch
    :timer.sleep(100)
    tx = API.TestHelper.create_encoded([{deposit_blknum, 0, 0, alice}], @eth, [{alice, 7}, {bob, 3}])
    {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx})

    wait_for_BlockGetter_get_block(block_nr)

    encode_tx = Client.encode(tx)

    assert [%{"amount" => 3, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(bob)

    assert [%{"amount" => 7, "blknum" => block_nr, "oindex" => 0, "txindex" => 0, "txbytes" => encode_tx}] ==
             get_utxo(alice)

    %{
      utxo_pos: utxo_pos,
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    } = compose_utxo_exit(block_nr, 0, 0)

    alice_address = "0x" <> Base.encode16(alice.addr, case: :lower)

    {:ok, txhash} =
      Eth.start_exit(
        utxo_pos * @block_offset,
        tx_bytes,
        proof,
        sigs,
        1,
        alice_address,
        contract.contract_addr
      )

    {:ok, _} = Eth.WaitFor.eth_receipt(txhash, @timeout)

    {:ok, height} = Eth.get_ethereum_height()

    assert {:ok, [%{amount: 7, blknum: block_nr, oindex: 0, owner: alice_address, txindex: 0, token: @eth}]} ==
             Eth.get_exits(0, height, contract.contract_addr)
  end

  @tag fixtures: [:watcher_sandbox, :alice]
  test "try consume block with invalid transaction", %{alice: alice} do
    assert {:error, :amounts_dont_add_up} ==
             OmiseGOWatcher.BlockGetter.consume_block(%Block{
               transactions: [API.TestHelper.create_signed([], @eth, [{alice, 1200}])],
               number: 1_000
             })

    assert {:error, :utxo_not_found} ==
             OmiseGOWatcher.BlockGetter.consume_block(%Block{
               transactions: [
                 API.TestHelper.create_signed([{1_000, 0, 0, alice}], @eth, [{alice, 1200}])
               ],
               number: 1_000
             })
  end

  #  @tag fixtures: [:watcher_sandbox, :contract,
  #                  :geth, :child_chain, :root_chain_contract_config, :alice, :carol, :bob]
  #  test "consume block with valid transactions", %{alice: alice, carol: carol, bob: bob, contract: contract} do
  #    [deposit_alice, deposit_bob] =
  #      [deposit_to_child_chain(alice, 1_000, contract), deposit_to_child_chain(bob, 1_000, contract)]
  #      |> Enum.map(&wait_for_deposit(&1, contract))
  #
  #    :timer.sleep(200)
  #
  #    block_nr =
  #      [
  #        API.TestHelper.create_encoded([{deposit_alice, 0, 0, alice}], @eth, [{alice, 700}, {carol, 200}]),
  #        API.TestHelper.create_encoded([{deposit_bob, 0, 0, bob}], @eth, [{carol, 500}, {bob, 400}])
  #      ]
  #      |> Enum.map(fn tx ->
  #        {:ok, %{"blknum" => block_nr}} = Client.call(:submit, %{transaction: tx})
  #        block_nr
  #      end)
  #      |> Enum.max()
  #
  #    wait_for_BlockGetter_get_block(block_nr)
  #    assert [%{"amount" => 700, "oindex" => 0}] = get_utxo(alice)
  #    assert [%{"amount" => 400, "oindex" => 0}] = get_utxo(bob)
  #    assert [%{"amount" => 200, "oindex" => 0}, %{"amount" => 500, "oindex" => 0}] = get_utxo(carol)
  #  end

  defp get_utxo(%{addr: address}) do
    decoded_resp = TestHelper.rest_call(:get, "account/utxo?address=#{Client.encode(address)}")
    decoded_resp["utxos"]
  end

  defp compose_utxo_exit(block_height, txindex, oindex) do
    decoded_resp =
      TestHelper.rest_call(
        :get,
        "account/utxo/compose_exit?block_height=#{block_height}&txindex=#{txindex}&oindex=#{oindex}"
      )

    {:ok, tx_bytes} = Client.decode(:bitstring, decoded_resp["tx_bytes"])
    {:ok, proof} = Client.decode(:bitstring, decoded_resp["proof"])
    {:ok, sigs} = Client.decode(:bitstring, decoded_resp["sigs"])

    %{
      utxo_pos: decoded_resp["utxo_pos"],
      tx_bytes: tx_bytes,
      proof: proof,
      sigs: sigs
    }
  end
end
