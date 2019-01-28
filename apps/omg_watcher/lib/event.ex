# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Watcher.Event do
  alias OMG.API.Block
  alias OMG.API.State.Transaction

  @type t ::
          OMG.Watcher.Event.AddressReceived.t()
          | OMG.Watcher.Event.InvalidBlock.t()
          | OMG.Watcher.Event.BlockWithholding.t()
          | OMG.Watcher.Event.InvalidExit.t()
          | OMG.Watcher.Event.UnchallengedExit.t()
          | OMG.Watcher.Event.NonCanonicalIFE.t()
          | OMG.Watcher.Event.InvalidIFEChallenge.t()

  #  TODO The reason why events have name as String and byzantine events as atom is that
  #  Phoniex websockets requires topics as strings + currently we treat Strings and binaries in
  #  the same way in `OMG.Watcher.Web.Serializers.Response`
  defmodule AddressReceived do
    @moduledoc """
    Notifies about received funds by particular address
    """

    defstruct [:tx, :child_blknum, :child_txindex, :child_block_hash, :submited_at_ethheight]

    @type t :: %__MODULE__{
            tx: Transaction.Recovered.t(),
            child_blknum: integer(),
            child_txindex: integer(),
            child_block_hash: Block.block_hash_t(),
            submited_at_ethheight: integer()
          }
  end

  defmodule AddressSpent do
    @moduledoc """
    Notifies about spent funds by particular address
    """

    defstruct [:tx, :child_blknum, :child_txindex, :child_block_hash, :submited_at_ethheight]

    @type t :: %__MODULE__{
            tx: Transaction.Recovered.t(),
            child_blknum: integer(),
            child_txindex: integer(),
            child_block_hash: Block.block_hash_t(),
            submited_at_ethheight: integer()
          }
  end

  defmodule InvalidBlock do
    @moduledoc """
    Notifies about invalid block
    """

    defstruct [:hash, :blknum, :error_type, name: :invalid_block]

    @type t :: %__MODULE__{
            hash: Block.block_hash_t(),
            blknum: integer(),
            error_type: atom(),
            name: atom()
          }
  end

  defmodule BlockWithholding do
    @moduledoc """
    Notifies about block-withholding
    """

    defstruct [:blknum, :hash, name: :block_withholding]

    @type t :: %__MODULE__{
            blknum: pos_integer(),
            hash: Block.block_hash_t(),
            name: atom()
          }
  end

  defmodule InvalidExit do
    @moduledoc """
    Notifies about invalid exit
    """

    defstruct [:amount, :currency, :owner, :utxo_pos, :eth_height, name: :invalid_exit]

    @type t :: %__MODULE__{
            amount: pos_integer(),
            currency: binary(),
            owner: binary(),
            utxo_pos: pos_integer(),
            eth_height: pos_integer(),
            name: atom()
          }
  end

  defmodule UnchallengedExit do
    @moduledoc """
    Notifies about an invalid exit, that is dangerously approaching finalization, without being challenged

    It is a prompt to exit
    """

    defstruct [:amount, :currency, :owner, :utxo_pos, :eth_height, name: :unchallenged_exit]

    @type t :: %__MODULE__{
            amount: pos_integer(),
            currency: binary(),
            owner: binary(),
            utxo_pos: pos_integer(),
            eth_height: pos_integer(),
            name: atom()
          }
  end

  defmodule NonCanonicalIFE do
    @moduledoc """
    Notifies about an in-flight exit which has a competitor
    """

    defstruct [:txbytes, name: :non_canonical_ife]

    @type t :: %__MODULE__{
            txbytes: binary(),
            name: atom()
          }
  end

  defmodule InvalidIFEChallenge do
    @moduledoc """
    Notifies about an in-flight exit which has a competitor
    """

    defstruct [:txbytes, name: :invalid_ife_challenge]

    @type t :: %__MODULE__{
            txbytes: binary(),
            name: atom()
          }
  end
end