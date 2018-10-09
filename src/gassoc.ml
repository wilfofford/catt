open Syntax
open Common
       
module type EVar = sig
  type t

  val make : var -> t
  val new_fresh : unit -> t
  val to_var : t -> var
  val to_string : t -> string
end                         
                       
module type EVal = sig
  type t

  val mk_coh : string -> (var * ty) list -> ty -> t
  val mk_let : string -> (var * ty) list -> tm -> t * string
  val mk_let_check : string -> (var * ty) list -> tm -> ty -> t * string
                       
  val suspend : t -> int -> t
  val functorialize : t -> int list -> var -> t

  val dim : t -> int
end
                     
module GAssoc (A : EVar) (B : EVal) = struct

  type a = A.t
  type t = B.t
             
  type gassoc =
    |Node of a * t
    |Inner of (a * t) * (int * gassoc) list * ((int list) * gassoc) list

  let env = ref ([] : gassoc list)

  let init () = env := []
                
  exception Found of t

  (** returns the association graph generated by the identifier v *)
  let assoc v g =
    let rec aux g =
      match g with
      |Node(v',res) when v = v' ->  raise (Found res)
      |Node(_,_) -> ()
      |Inner((v',res),_,_) when v = v' -> raise (Found res) 
      |Inner(_,l,l') ->
        let f = (fun x -> aux (snd x)) in
        begin List.iter f l; List.iter f l' end
    in
    try aux g; raise Not_found
    with Found r -> r

  (** returns the association graph generated by the identifier v in the environnement *)
  let assoc v =
    let rec aux env =
      match env with
      |[] -> raise Not_found
      |g::env ->
        try assoc v g
        with Not_found -> aux env
    in aux (!env)

  let top_value g =
    match g with
    |Node(v,res) -> v,res
    |Inner((v,res),_,_) -> v,res
    
  (** follow an already existing suspension edge or add a new one *)
  let rec suspend v i g =
    match g with
    |Node(w,value) when w = v ->
      let n = A.new_fresh() in
      let newval = B.suspend value i in
      Inner ((w,value) ,[i, Node (n, newval)],[]), Some newval
    |Node(_,_) as g -> g, None 
    |Inner((w,value),susp,func) as g when w = v ->
      begin
        try let res = List.assoc i susp in g, Some (snd (top_value res))            
        with Not_found ->
          let n = A.new_fresh() in
          let newval = B.suspend value i in
          let susp = (i, Node (n, newval))::susp
          in Inner((w,value),susp,func),Some newval
      end
    |Inner(p,l,l') ->
      let rec suspend_list l =
        match l with
        |[] -> [],None
        |(k,g)::l ->
          let g,value = suspend v i g in
          match value with
          |None -> let l,res = suspend_list l in (k,g)::l, res
          |Some res -> (k,g)::l, Some res
      in    
      let l,r = suspend_list l in
      match r with
      | None -> let l',r = suspend_list l' in
                Inner(p,l,l'), r
      | Some res -> Inner(p,l,l'), Some res

  (** perform the suspension successively on all graphs on the list until finding the right one *)
  let suspend v i =
    let rec aux env =
      match env with
      |[] -> raise Not_found
      |g::env ->
        let g,r = suspend v i g
        in match r with
           |Some res -> g::env, res
           |None -> let env,res = aux env in g::(env),res
    in let newenv,res = aux (!env) in
       env:=newenv; res

  let rec functorialize v f g x =
    match g with
    |Node(w,value) when w = v ->
      let n = A.new_fresh() in
      let newval = B.functorialize value f x in
      Inner ((w,value),[],[f, Node (n, newval)]), Some (n,newval)
    |Node(_,_) as g -> g, None
    |Inner((w,value),susp,func) as g when w = v ->
      begin
        try let res = List.assoc f func in g, Some (top_value res)
        with Not_found ->
          let n = A.new_fresh() in
          let newval = B.functorialize value f x in
          let func = (f, Node (n, newval))::func
          in Inner((w,value),susp,func), Some (n,newval)
      end
    |Inner(p,l,l') -> 
      let rec functorialize_list l =
        match l with
        |[] -> [],None
        |(k,g)::l ->
          let g,value = functorialize v f g x in
          match value with
          |None -> let l,res = functorialize_list l in (k,g)::l, res
          |Some res -> (k,g)::l, Some res
      in
      let l,r = functorialize_list l in
      match r with
      |None -> let l',r = functorialize_list l' in
               Inner(p,l,l'), r
      |Some res -> Inner(p,l,l'),Some res

  let functorialize v f x =
    let rec aux env =
      match env with
      |[] -> raise Not_found
      |g::env ->
        let g,r = functorialize v f g x
        in match r with
           |Some res -> g::env, res
           |None -> let env,res = aux env in g::(env),res
    in let newenv,res = aux (!env) in
       env:=newenv; res


  (** Add a variable together with the corresponding coherence*)
  let add_coh x ps t =
    let t = B.mk_coh (string_of_var x) ps t in
    let x = A.make x in
    env := Node (x,t)::!env

  (** Add a variable together with the corresponding let term*)
  let add_let x c u =
    (* debug "adding %s" (Var.to_string x); *)
    let u,msg = B.mk_let (string_of_var x) c u in
    let x = A.make x in
    env := Node (x,u)::!env;
    msg

  (** Add a variable together with the corresponding let term whose type is checked by the user*)
  let add_let_check x c u t =
    (* debug "adding %s" (Var.to_string x); *)
    let u,msg = B.mk_let_check (string_of_var x) c u t in
    let x = A.make x in
    env := Node (x,u)::!env;
    msg

      
  (** Retrieves the value associated to a variable in the environment, with possible suspension and functorialisations*)
  let val_var x i func =
    let x,value = functorialize x func (A.to_var x) in
    let dim = B.dim value in
    let i = i - dim in
    if i >= 1 then x,suspend x i
    else x,value           

end
