defmodule OmiseGOWatcher.Repo.Migrations.CreateUtxo do
  use Ecto.Migration

  def change do
    create table(:utxos) do
      add :address, :string, null: false
      add :amount, :integer, null: false
      add :blknum, :integer, null: false
      add :oindex, :integer, null: false
      add :txbytes, :text, null: false
      add :txindex, :integer, null: false
    end
  end

end
