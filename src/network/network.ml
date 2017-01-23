open Block;;
open Log;;
open Dns;;
open Params;;
open Peer;;
open Message;;
open Blockchain;;

type t = {
	addrs:  Unix.inet_addr list;
	peers:	(string, Peer.t) Hashtbl.t;
	params: Params.t;
};;



let init p =
	let rec init_peers par pt addrs n =
		match (n, addrs) with
		| (0, a::al') -> pt
		| (0, []) -> pt
		| (n', []) -> pt
		| (n', a::al') ->  
			let a' = Unix.string_of_inet_addr a in
			try
				let _ = Hashtbl.find pt a' in
				init_peers par pt al' n 
			with Not_found -> 
				let peer = Peer.create par a par.port in
				Hashtbl.add pt a' peer;
				init_peers par pt al' (n-1)
	in
	Log.info "Network" "Initalization...";
 	let addrs = Dns.query_set p.seeds in
	let peers = init_peers p (Hashtbl.create 16) addrs 4 in
	Log.info "Network" "Connected to %d peers." (Hashtbl.length peers);
	Log.info "Network" "Initalization done.";
	{ addrs= addrs; peers= peers; params= p }
;;


let loop n bc = 
	Log.info "Network" "Starting mainloop.";
	
	Hashtbl.iter (fun k peer -> Thread.create (Peer.start peer) bc; ()) n.peers;
					
	while true do
		Unix.sleep 5;
		
		(* Check for connection timeout and minimum number of peer*)		
		Hashtbl.iter (fun k peer -> 
			match peer.last_seen with
			| x when x < (Unix.time () -. 60. *. 3.) ->
				Peer.disconnect peer;
				Hashtbl.remove n.peers k;
				Log.info "Network" "Peer %s disconnected for inactivity" k;
				if Hashtbl.length n.peers < 4 then ()
				else ()
			| x when x < (Unix.time () -. 60. *. 1.) ->
				Peer.send peer (PING (Random.int64 0xFFFFFFFFFFFFFFFL))
			| _ -> () 
		) n.peers;
		
		(* Check for request *)
		Log.info "Network" "Pending request from blockchain: %d" (Queue.length bc.queue_req);

		let reqo = Blockchain.get_request bc in	
		match reqo with
		| None -> ()
		| Some (req) ->
			Hashtbl.iter (fun k peer -> 
				match req with
				| REQ_HBLOCKS (h, addr)	->
					let msg = {
						version= Int32.of_int 1;
						hashes= h;
						stop= Hash.zero ();
					} in Peer.send peer (Message.GETHEADERS msg)
			) n.peers;
	done;
	()
;;
