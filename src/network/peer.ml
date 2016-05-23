open Unix;;
open Log;;
open Message;;
open Params;;
open Random;;

type t = {
	socket	: Unix.file_descr;
	address : Unix.inet_addr;
	port	: int;
	params	: Params.t;
};;



let connect params addr port =
	Log.debug "Peer" "Connecting to peer %s:%d..." (Unix.string_of_inet_addr addr) port;
	let psock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
	try
		Unix.connect psock (ADDR_INET (addr, port));
		Log.debug "Peer" "Connected to peer %s:%d" (Unix.string_of_inet_addr addr) port;						
		Some { socket= psock; address= addr; port= port; params= params }
	with
		| _ -> 
			Log.error "Peer" "Failed to connect to peer %s:%d." (Unix.string_of_inet_addr addr) port;
			None
;;



let send peer message = 
	let data = Message.serialize peer.params message in
	Unix.send peer.socket data 0 (Bytes.length data) [] |> ignore
;;


let recv p = None;;



let handshake peer =
	let verm = {
		version		= Int32.of_int peer.params.version;
		services	= peer.params.services;
		timestamp	= Unix.gmtime (Unix.time ());
		addr_recv	= { address="0000000000000000" ; services=(Int64.of_int 1) ; port= 8333 };
		addr_from	= { address="0000000000000000" ; services=(Int64.of_int 1) ; port= 8333 };
		nonce		= Random.int64 0xFFFFFFFFFFFFFFFL;
		user_agent	= "/letchain:0.12.1/";
		start_height= Int32.of_int 0;
		relay		= true;
	} in send peer (Message.VERSION (verm))
;;
