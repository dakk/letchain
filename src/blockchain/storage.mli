open Stdint
open LevelDB
open Tx
open Block
open Block.Header


module Address : sig
	type t = {
		mutable balance			: uint64;
		mutable sent			: uint64;
		mutable received		: uint64;
		mutable txs				: uint64;
	}

	val parse 			: bytes -> t
	val serialize 		: t -> bytes
	val load_or_create 	: LevelDB.db -> string -> t
	val save 			: LevelDB.db -> string -> t -> unit
end

module Chainstate : sig 
	type t = {
		mutable block           : Hash.t;
		mutable height       	: uint32;

		mutable header        	: Hash.t;
		mutable header_height 	: uint32;

		mutable txs				: uint64;
		mutable utxos			: uint64;
	}

	val serialize	: 	t -> bytes
	val parse		: 	bytes -> t
end

type t = {
	chainstate		:	Chainstate.t;
    db       		:   LevelDB.db;
}


val load					:	string -> t
val close 					:	t -> unit
val sync					:	t -> unit 

val insert_header      		:   t -> int64 -> Block.Header.t -> unit
val insert_block            :   t -> int64 -> Block.t -> unit

val get_utx					:	t -> Hash.t -> int -> Tx.Out.t option
val get_blocki              :   t -> Int64.t -> Block.t option
val get_block               :   t -> Hash.t -> Block.t option
val get_header				:	t -> Hash.t -> Block.Header.t option
val get_headeri				:	t -> Int64.t -> Block.Header.t option
val get_tx					:	t -> Hash.t -> Tx.t option
val get_blocks 				:	t -> Hash.t list -> Block.t list
val get_headers				:	t -> Hash.t list -> Block.Header.t list
val get_address				:	t -> string -> Address.t

