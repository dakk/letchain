open Bitstring;;
open Params;;
open Crypto;;

type header = {
	magic		: int32;
	command		: string;
	length		: int32;
	checksum	: string;
};;


type addr = {
	services	: int64;
	address		: string;
	port		: int
};;

type version = {
	version		: int32;
	services	: int64;
	timestamp	: Unix.tm;
	addr_recv	: addr;
	addr_from	: addr;
	nonce		: int64;
	user_agent	: string;
	start_height: int32;
	relay		: bool;
};;



type ping = int64;;
type pong = int64;;


type t = 
	  VERSION of version
	| VERACK
	| PING of ping
	| PONG of pong
	| INV
	| ADDR
	| GETDATA
	| NOTFOUND
	| GETBLOCKS
	| GETHEADERS
	| TX
	| BLOCKS
	| HEADERS
	| GETADDR
	| MEMPOOL
	| REJECT
	
	(* Bloom filter related *)
	| FILTERLOAD
	| FILTERADD
	| FILTERCLEAR
	| MERKLEBLOCK
	
	| ALERT
	| SENDHEADERS
;;


let string_of_command c = match c with
	  VERSION (v) -> "version"
	| VERACK -> "verack"
	| PING (p) -> "ping"
	| PONG (p) -> "pong"
	| INV -> "inv"
	| ADDR -> "addr"
	| GETDATA -> "getdata"
	| NOTFOUND -> "notfound"
	| GETBLOCKS -> "getblocks"
	| GETHEADERS -> "getheaders"
	| TX -> "tx"
	| BLOCKS -> "blocks"
	| HEADERS -> "headers"
	| GETADDR -> "getaddr"
	| MEMPOOL -> "mempool"
	| REJECT -> "reject"
	
	(* Bloom filter related *)
	| FILTERLOAD -> "filterload"
	| FILTERADD -> "filteradd"
	| FILTERCLEAR -> "filterclear"
	| MERKLEBLOCK -> "merkleblock"
	
	| ALERT -> "alert"
	| SENDHEADERS -> "sendheaders"
;;


(******************************************************************)
(* Parsing ********************************************************)
(******************************************************************)
let string_from_zeroterminated_string zts =
  let string_length =
    try
      String.index zts '\x00'
    with Not_found -> 12
  in
  String.sub zts 0 string_length
;;


let parse_version data =
	""
;;

let parse_ping data =
	let bdata = bitstring_of_string data in
	bitmatch bdata with
	| { nonce		: 8*8	: littleendian } -> nonce
	| { _ } -> raise (Invalid_argument "Invalid ping message")
;;

let parse_pong data =
	let bdata = bitstring_of_string data in
	bitmatch bdata with
	| { nonce		: 8*8	: littleendian } -> nonce
	| { _ } -> raise (Invalid_argument "Invalid pong message")
;;



let parse_header data =
	let bdata = bitstring_of_string data in
	bitmatch bdata with
	| { 
		magic 		: 4*8 	: littleendian;
		command 	: 12*8 	: string;
		length 		: 4*8 	: littleendian;
		checksum	: 4*8 	: string
	} ->
	{
		magic 		= magic;
		command 	= string_from_zeroterminated_string command;
		length 		= length;
		checksum	= checksum;
		}
	| { _ } -> raise (Invalid_argument "Invalid protocol header")
;;


let parse header payload = 
	match header.command with
	| "version" -> VERACK
	| "ping" -> PING (parse_ping payload)
	| "pong" -> PONG (parse_pong payload)
	| "verack" -> VERACK
	| "getaddr" -> GETADDR
	| "mempool" -> MEMPOOL
	| "sendheaders" -> SENDHEADERS
	| "getheaders" -> GETHEADERS
	| "inv" -> INV
	| _ -> raise (Invalid_argument ("Protocol command " ^ header.command ^ " not recognized"))
;;








(******************************************************************)
(* Serialization **************************************************)
(******************************************************************)
let bitstring_of_addr (addr: addr) : Bitstring.t =
  BITSTRING {
    addr.services	: 8*8 	: littleendian;
    addr.address	: 16*8 	: string;
    addr.port		: 2*8 	: bigendian
  }
;;

let bitstring_of_int i = 
	match i with
	| i when i < 0xFDL -> BITSTRING { Int64.to_int i : 1*8 : littleendian }
	| i when i < 0xFFFFL -> BITSTRING { 0xFD : 1*8; Int64.to_int i : 2*8 : littleendian }
	| i when i < 0xFFFFFFFFL -> BITSTRING { 0xFE : 1*8; Int64.to_int32 i : 4*8 : littleendian }
	| i -> BITSTRING { 0xFF : 1*8; i : 8*8 : littleendian }
;;

let bitstring_of_varstring s = 
	match String.length s with
	| 0 -> bitstring_of_string "\x00"
	| n -> 
		let length_varint_bitstring = bitstring_of_int (Int64.of_int (String.length s)) in
		BITSTRING {
			length_varint_bitstring : -1 : bitstring;
			s 						: (String.length s) * 8 : string
		}
;;

let int_of_bool b = 
	match b with
	| true -> 1
	| false -> 0
;;

let serialize_version v =
	BITSTRING {
		v.version 										: 4*8 : littleendian;
		v.services 										: 8*8 : littleendian;
		Int64.of_float (fst (Unix.mktime v.timestamp)) 	: 8*8 : littleendian;
		(bitstring_of_addr v.addr_recv)					: -1 : bitstring;
		(bitstring_of_addr v.addr_from)			 		: -1 : bitstring;
		v.nonce											: 8*8 : littleendian;
		bitstring_of_varstring v.user_agent 			: -1 : bitstring;
		v.start_height 									: 4*8 : littleendian;
		int_of_bool true								: 1*8 : littleendian
	}
;;

let serialize_ping p = BITSTRING { p 	: 8*8 : littleendian };;
let serialize_pong p = BITSTRING { p 	: 8*8 : littleendian };;

let serialize_header header =
	let bdata = BITSTRING {
		header.magic 	: 4*8 	: littleendian;
		header.command	: 12*8 	: string;
		header.length 	: 4*8 	: littleendian;
		header.checksum : 4*8 	: string
	} 
	in string_of_bitstring bdata
;;


let serialize_message message = 
	let bdata = match message with
	| PING (p) -> serialize_ping p
	| PONG (p) -> serialize_pong p
	| VERSION (v) -> serialize_version v
	| VERACK -> empty_bitstring
	| GETADDR -> empty_bitstring
	| MEMPOOL -> empty_bitstring
	| SENDHEADERS -> empty_bitstring
	| _ -> empty_bitstring
	in string_of_bitstring bdata
;;

let serialize params message = 
	let mdata = serialize_message message in
	let command = string_of_command message in
	let command' = command ^ (String.make (12 - (String.length command)) '\x00') in
	let header = {
		magic	= Int32.of_int params.Params.magic;
		command	= command';
		length	= Int32.of_int (Bytes.length mdata);
		checksum= Crypto.checksum4 mdata;
	} in 
	let hdata = serialize_header header in
	Bytes.cat hdata mdata
;;