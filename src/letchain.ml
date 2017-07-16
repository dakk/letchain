open Network;;
open Utils;;
open Blockchain;;
open Thread;;
open Random;;
open Config;;

let main () =
	let chain_job bc = 
		Chain.loop bc 
	in
	let net_job (bc, conf) = 
		let n = Net.init bc.Chain.params conf.peers in 
		Net.loop n bc
	in
	let api_job (bc, conf) =
		Api.loop conf.api_port bc
	in
	
	Random.self_init ();
	Log.info "letchain" "Starting 0.1";
	let conf = Config.load_or_init () |> Config.parse_command_line in
 	let cn = Params.abbr_to_network conf.chain in
	if cn = NOTFOUND then
		Log.info "letchain" "Invalid chain"
	else 	
		Log.info "letchain" "Selected network: %s" (Params.name_of_network cn);
		let p = Params.of_network cn in	
		
		let bc = Chain.load conf.path p in
		let chain_thread = Thread.create chain_job bc in
		let api_thread = Thread.create api_job (bc, conf) in
		let net_thread = Thread.create net_job (bc, conf) in
		
		Log.info "letchain" "Waiting for childs";
		Thread.join net_thread;
		Thread.join chain_thread;
		Thread.join api_thread;
		Log.info "letchain" "Exit.";
;;

main ();;
