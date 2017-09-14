open Stdlib
open Common

       
exception NotValid
exception NotAlgebraic
exception UnknownId of string
exception UnknownCoh of string
exception IsNotType of string
exception HasNoType of string
exception NotEqual of string*string
			 
module Var = struct
  type t =
  |Name of string
  |New of string * int

  let to_string v abbrev show_instances =
  match v with
  |Name s -> s
  |New (s,i) -> if not(abbrev)&&show_instances then Printf.sprintf "%s.%d" s i else s
end


module EVar = struct
  type t =
  |Name of string
  |New of string * int

  let to_string v abbrev show_instances =
  match v with
  |Name s -> s
  |New (s,i) -> if not(abbrev)&&show_instances then Printf.sprintf "%s.%d" s i else s
end

	       

module rec Sub 
: sig
  type t = private (Expr.t list * Ctx.t * Ctx.t)
  val list : t -> Expr.t list
  val source : t -> Ctx.t
  val target : t -> Ctx.t
  val assoc_list : t -> ((Var.t * Expr.t) list)
  val mk : Env.t -> Expr.t list -> Ctx.t -> Ctx.t -> t
  val checkEqual : Env.t -> t -> t -> unit
  val to_string : t -> bool -> bool -> string
end
= struct
    type t = (Expr.t list * Ctx.t * Ctx.t)
	     
  let list (s:t) =
    match s with 
    |l,_,_ -> l

  let source (s:t) = 
    match s with
    |_,src,_ -> src

  let target (s:t) =
    match s with
    |_,_,targ -> targ
    
  let assoc_list (s:t) = 
    let rec build l ctx =
      match l,ctx with
      |t::l,(x,_)::ctx -> (x,t)::(build l ctx)
      |[],[] -> []
      |_,_ -> assert (false)
    in build (list s) (Ctx.value (target s))
    	     
  let mk env s delta gamma =                       
    let rec check_list env s delta gamma =
      match s,(Ctx.value gamma) with
      |([],c) when c = Ctx.value (Ctx.empty ()) -> ()
      |(t::s, (x,u)::_) -> let gamma = Ctx.tail gamma in
                           Infer.checkT env gamma u;
                           let s = Sub.mk env s delta gamma in
                           Infer.checkType env delta t (Expr.subst u s)
      |_ -> raise NotValid
    and make env s delta gamma : t =
      check_list env s delta gamma; (s,delta,gamma)            
    in make env (List.map (Infer.normalize env gamma) s) delta gamma

				    
  let rec string_of_assoc s abbrev show_instances =
    match s with
    |[] -> ""
    |(x,u)::s -> Printf.sprintf "(%s,%s) %s" (Var.to_string x abbrev show_instances)
                                             (Expr.to_string u abbrev show_instances)
                                             (string_of_assoc s abbrev show_instances)

  let rec string_of_list s abbrev show_instances =
    match s with
    |[] -> ""
    |u::s -> Printf.sprintf "%s; %s" (Expr.to_string u abbrev show_instances)
                                     (string_of_list s abbrev show_instances)

  let checkEqual env s1 s2 =
    let () = Ctx.checkEqual env (source s1) (source s2) in
    let () = Ctx.checkEqual env (target s1) (target s2) in
    let ctx = source s1 in
    let rec equal_list s1 s2 = 
      match s1,s2 with
      |[],[] -> ()
      |t1::s1,t2::s2 -> Infer.checkEqual_norm env ctx t1 t2; equal_list s1 s2
      |_,_ -> raise NotValid
    in equal_list (list s1) (list s2)
    
				     
  let to_string s abbrev show_instances =
    if abbrev then Printf.sprintf "[%s]" (string_of_assoc (assoc_list s) abbrev show_instances)
    else Printf.sprintf "(%s |- %s : %s)" (Ctx.to_string (source s) abbrev show_instances)
                                         (string_of_list (list s) abbrev show_instances)
                                         (Ctx.to_string (target s) abbrev show_instances)  
end

                      
and Ctx
: sig
  type t = private ((Var.t * Expr.t) list)
  val value : t -> ((Var.t * Expr.t) list)      
  val ty_var : t -> Var.t -> Expr.t
  val empty : unit -> t
  val add : Env.t -> t -> Var.t -> Expr.t -> t 
  val of_ps : PS.t -> t
  val checkEqual : Env.t -> t -> t -> unit
  val tail : t -> t
  val free_vars : t -> Var.t list
  val mem : t -> Var.t -> bool
  val to_string : t -> bool -> bool -> string
end
= struct
  type t = (Var.t * Expr.t) list
                        
  let ty_var ctx x = try List.assoc x ctx with Not_found -> raise (UnknownId (Var.to_string x true false))

  let empty _ = []

		
  let add env (ctx :Ctx.t) x u = let u = Infer.normalize env ctx u in
			     let () = Infer.checkT env ctx u in
			     (ctx :> t)@[(x,u)] 
						 
  let value ctx = ctx
    
  let rec of_ps ps =
    let open PS in
    match ps with
    |PNil (x,t) ->  [(x,t)]
    |PCons (ps,(x1,t1),(x2,t2)) -> (of_ps ps)@[(x1,t1);(x2,t2)]
    |PDrop ps -> of_ps ps


  let rec checkEqual env ctx1 ctx2 =
    let rec equal c ctx1 ctx2 = 
      match ctx1, ctx2 with
      |[],[] -> ()
      |(v1,x1)::ctx1, (v2,x2)::ctx2 -> if not (v1 = v2) then raise NotValid;
                                       Infer.checkEqual_norm env c x1 x2;
                                       equal (Ctx.add env c v1 x1) ctx1 ctx2
      |_,_ -> raise NotValid
    in equal (Ctx.empty ()) ctx1 ctx2

             
 let rec tail ctx = match ctx with 
   |[] -> assert(false)
   |_::[] -> []
   |a::ctx -> a::(tail ctx)

 let free_vars ctx = List.map fst ctx

 let rec mem c v = match c with
   |[] -> false
   |(x,u)::c when x = v -> true
   |_::c -> mem c v
			      
 let rec to_string ctx abbrev show_instances =
   let to_string = (fun c -> to_string c abbrev show_instances) in
   match ctx with
   |[] -> ""
   |(x,t)::c -> Printf.sprintf "(%s,%s) %s" (Var.to_string x abbrev show_instances)
                                            (Expr.to_string t abbrev show_instances)
                                            (to_string c)
end

and PS
: sig
  type t = private
          |PNil of (Var.t * Expr.t)
          |PCons of t * (Var.t * Expr.t) * (Var.t * Expr.t)
          |PDrop of t
                      
  val free_vars : t -> Var.t list
  val mk : Ctx.t -> t
  val height : t -> int
  val dim : t -> int
  val source : int -> t -> t
  val target : int -> t -> t
  val to_string : t -> bool -> bool -> string
end
= struct
  exception Invalid
  
  (** --Syntactic properties-- *)
  type t =
    |PNil of (Var.t * Expr.t)
    |PCons of PS.t * (Var.t * Expr.t) * (Var.t * Expr.t)
    |PDrop of PS.t

  let free_vars ps = Ctx.free_vars (Ctx.of_ps ps)
		
  (** --Maker-- *)
  (** Dangling variable. *)
  let rec marker ps =
    match ps with
    | PNil (x,t) -> x,t
    | PCons (ps,_,f) -> f
    | PDrop ps ->
       let f,tf = marker ps in
       match tf with
       | Expr.Arr (_,x,Expr.CVar y) ->
          let t =
            let rec aux = function
              | PNil (x,t) -> assert (x = y); t
              | PCons (ps,(y',ty),(f,tf)) ->
                 if y' = y then ty
                 else if f = y then tf
                 else aux ps
              | PDrop ps -> aux ps
            in
            aux ps
          in
          y,t
       | _ -> raise Invalid


  (** Create pasting scheme from a context. *)
  let mk l : t =
    let open Expr in 
    let x0,l =
      match l with
      | (x,Obj)::l -> x,l
      | _ -> raise Invalid
    in
    let rec aux ps = function
      | (y,ty)::(f,tf)::l ->
         begin
           match tf with
           | Arr (_, CVar fx, CVar fy) ->
              if (y <> fy) then raise Invalid;
              let x,tx = marker ps in
              if x = fx then
                let fvps = PS.free_vars ps in
                assert (not (List.mem f fvps));
                assert (not (List.mem y fvps));
                let ps = PCons (ps,(y,ty),(f,tf)) in
                aux ps l
              else
                aux (PDrop ps) ((y,ty)::(f,tf)::l)
           | _ -> raise Invalid
         end
      | [x,tx] -> raise Invalid
      | [] -> ps
    in
    aux (PNil(x0,Obj)) l

	
  (** --Manipulations-- *)
  (** Height of a pasting scheme. *)
  let rec height = function
    | PNil _ -> 0
    | PCons (ps,_,_) -> height ps + 1
    | PDrop ps -> height ps - 1

  (** Dimension of a pasting scheme. *)
  let rec dim = function
    | PNil _ -> 0
    | PCons (ps,_,_) -> max (dim ps) (height ps + 1)
    | PDrop ps -> dim ps

  (** Source of a pasting scheme. *)
  let source i ps =
    assert (i >= 0);
    let rec aux = function
      | PNil _ as ps -> ps
      | PCons (ps,_,_) when height ps >= i -> aux ps
      | PCons (ps,y,f) -> PCons (aux ps,y,f)
      | PDrop ps when height ps > i -> aux ps
      | PDrop ps -> PDrop (aux ps)
    in
    aux ps

  (** Target of a pasting scheme. *)
  let target i ps =
    assert (i >= 0);
    let replace g = function
      | PNil x -> PNil g
      | PCons (ps,y,f) -> PCons (ps,y,g)
      | _ -> assert false
    in
    let rec aux = function
      | PNil _ as ps -> ps
      | PCons (ps,_,_) when height ps > i -> aux ps
      | PCons (ps,y,f) when height ps = i -> replace y (aux ps)
      | PCons (ps,y,f) -> PCons (aux ps,y,f)
      | PDrop ps when height ps > i -> aux ps
      | PDrop ps -> PDrop (aux ps)
    in
    aux ps

  let rec map f = function
    | PNil x -> PNil (f x)
    | PCons (ps,x,y) ->
       let ps = map f ps in
       let x = f x in
       let y = f y in
       PCons (ps,x,y)
    | PDrop ps -> PDrop (map f ps)
        
  let to_string ps abbrev show_instances =
    Ctx.to_string (Ctx.of_ps ps) abbrev show_instances
end

and Env
: sig
  type t = private (EVar.t * Coh.t) list
  (*a function is required here for the safe module condition*)
  val empty : unit -> t
  val val_var : t -> EVar.t -> Coh.t
  val add : t -> EVar.t -> Coh.t -> t 
end
= struct
  type t = (EVar.t * Coh.t) list

  let value env = env

  let empty a = []
                    
  let val_var env x = try List.assoc x env with Not_found -> raise (UnknownCoh (EVar.to_string x true false))
					
  let add env x u =
    (x,u)::env
end

    
and Expr
: sig
  type t = 
    |CVar of Var.t
    |Obj
    |Arr of t * t * t
    |PArr of t * t
    |Sub of ecoh * Sub.t
   and ecoh =
    |Fold of EVar.t
    |Unfold of Coh.t

  val free_vars : t -> Var.t list
  val subst : t -> Sub.t -> t
  val to_string : t -> bool -> bool  -> string
end
= struct
  type  t =
    |CVar of Var.t
    |Obj
    |Arr of t * t * t
    |PArr of t * t
    |Sub of ecoh * Sub.t
  and ecoh =
    |Fold of EVar.t
    |Unfold of Coh.t

  let rec free_vars e =
    match e with
    |CVar x -> [x]
    |Obj -> []
    |Arr (t,u,v) -> List.unions [(free_vars t);(free_vars u);(free_vars v)]
    |PArr (u,v) -> assert(false)
    |Sub (_,sub) -> Ctx.free_vars (Sub.source sub)
  (** We should check that the target of the substitution is the pasting scheme of the EVar at some point*)
  and free_vars_ecoh coh =
    match coh with
     |Fold x -> assert (false) (** Ignore this case for now*)
     |Unfold coh -> Coh.free_vars coh 
   		       
(** Performs all possible substitutions *)
  let rec subst t s =
    match t with
    |CVar x -> List.assoc x (Sub.assoc_list s)
    |Obj -> Obj
    |Arr (a,u,v) -> Arr (subst a s, subst u s, subst v s)
    |PArr(u,v) -> PArr (subst u s, subst v s)
    |Sub _ -> assert (false)
  (** We are not supposed to perform mutliple substitutions on one term*)
  
  let rec to_string expr abbrev show_instances =
    let to_string  = fun u -> Expr.to_string u abbrev show_instances in 
    match expr with
    |CVar x -> Var.to_string x abbrev show_instances
    |Obj -> "*"
    |Arr (t,u,v) -> if abbrev then
                      Printf.sprintf "%s -> %s" (to_string u) (to_string v)
                    else Printf.sprintf "%s | %s -> %s" (to_string t) (to_string u) (to_string v)
    |PArr (u,v) -> Printf.sprintf "%s -> %s" (to_string u) (to_string v)
    |Sub (t,s) -> Printf.sprintf "%s.%s" (Sub.to_string s abbrev show_instances) (ecoh_to_string t abbrev show_instances)
  and ecoh_to_string coh abbrev show_instances=
    match coh with
    |Fold x -> EVar.to_string x abbrev show_instances
    |Unfold coh -> Coh.to_string coh abbrev show_instances
end

(** -- Module with a specific type for well-defined coherences
    -- They are different from normal type, they need to be substituted *)    
and Coh    
: sig
  type t = private (PS.t * Expr.t)   

  val mk : Env.t -> PS.t -> Expr.t -> t
  val free_vars : t -> Var.t list
  val to_string : t -> bool -> bool -> string
  val checkEqual : Env.t -> t -> t -> unit
  val ps : t -> PS.t
  val target : t -> Expr.t
end
= struct
  type t = PS.t * Expr.t
		    
  let mk env ps t =
    let ctx = Ctx.of_ps ps in
    let t = Infer.normalize env ctx t in
    Infer.checkT env ctx t;
    if List.included (PS.free_vars ps) (Expr.free_vars t)
    then  (ps,t)
    else
      let open Expr in
      let f,g = match t with
        |Arr(a,f,g) -> (f,g)  
        |_ -> raise NotAlgebraic
      in
      let i = PS.dim ps in
      let pss = PS.source (i-1) ps
      and pst = PS.target (i-1) ps in
      let ctxs = Ctx.of_ps pss
      and ctxt = Ctx.of_ps pst in
      let tf = Infer.infer env ctx f in
      (** Replace ctx by ctxs => handle substitutions better*)
      let tg = Infer.infer env ctx g in
      (** Replace ctx by ctxt => handle substitutions better*)
      begin
	Infer.checkT env ctxs tf;
	Infer.checkT env ctxt tg;
       if List.included (PS.free_vars pss) (free_vars f) && List.included (PS.free_vars pst) (free_vars g)
       then () 
       else raise NotAlgebraic
      end;
      (ps,t)
	

  let free_vars (ps,t) =
    List.union (PS.free_vars ps) (Expr.free_vars t)

  let to_string (ps,t) abbrev show_instances=
    Printf.sprintf "Coh {%s |- %s}"
		   (PS.to_string ps abbrev show_instances)
		   (Expr.to_string t abbrev show_instances)

  let checkEqual env (ps1,t1) (ps2,t2) =
    let c1 = Ctx.of_ps ps1 and c2 = Ctx.of_ps ps2 in
    Ctx.checkEqual env c1 c2;
    Infer.checkEqual env c1 t1 t2

  let ps (ps,t) = ps

  let target (ps,t) = t

end    
    
and Infer
: sig
  val checkT : Env.t -> Ctx.t -> Expr.t -> unit
  val infer : Env.t -> Ctx.t -> Expr.t -> Expr.t
  val checkEqual_norm : Env.t -> Ctx.t -> Expr.t -> Expr.t -> unit
  val checkEqual : Env.t -> Ctx.t -> Expr.t -> Expr.t -> unit
  val checkType : Env.t -> Ctx.t -> Expr.t -> Expr.t -> unit
  val normalize : Env.t -> Ctx.t -> Expr.t -> Expr.t
end
= struct
    
(** Normalization of an expression *)
  let rec normalize env ctx e =
    let open Expr in
    match e with
    |CVar x -> CVar x
    |Obj -> e
    |Arr (t,u,v) ->
      Arr (normalize env ctx t, normalize env ctx u, normalize env ctx v)
    |PArr (u,v) ->
      let u = normalize env ctx u and v = normalize env ctx v in
      let t = Infer.infer env ctx u and t' = Infer.infer env ctx v in
      let _ = Infer.checkEqual env ctx t t' in
       Arr (normalize env ctx t,u,v)
    |Sub (t,s) -> let t = unfold env t in
                  Sub (t,s)
  and unfold env coh =
    let open Expr in
    match coh with
    |Fold x -> Unfold (Env.val_var env x)
    |Unfold coh -> Unfold coh
  (** For now we always unfold completely all the terms*)

			  
  (** Checks the equality of two terms *)
   let rec checkEqual_norm env ctx e1 e2 =
    let open Expr in
    let equal = checkEqual_norm env ctx in
    match e2, e2 with
    |CVar x,CVar y -> if not (x = y) then raise (NotEqual (Expr.to_string e1 true false, Expr.to_string e2 true false)) else ()
    |Obj,Obj -> ()
    |Arr(t1,u1,v1),Arr(t2,u2,v2) ->
      equal t1 t2;
      equal u1 u2;
      equal v1 v2
    |Sub(t1,s1),Sub(t2,s2) ->
      checkEqual_ecoh env t1 t2;
      Sub.checkEqual env s1 s2
    |(PArr _, _ |_, PArr _) -> assert (false)
    (** Not a normal form*)
    |(CVar _|Obj |Arr _|Sub _),_ ->
      raise (NotEqual (Expr.to_string e1 true false, Expr.to_string e2 true false)) 
  and checkEqual_ecoh env e1 e2 =
    let open Expr in
    match e1, e2 with
    |Unfold coh1, Unfold coh2 -> Coh.checkEqual env coh1 coh2
    |(Fold _, _ |_, Fold _) -> assert (false)
   (** If we don't allow the cut rule, this case should be excluded *)
    (** allowing cut rule : this case should be
	|Fold x, y -> checkEqual_norm (val_var x) y 
	and its symmetric case*)
						      
  let checkEqual env ctx e1 e2 =
    checkEqual_norm env ctx
		    (normalize env ctx e1)
		    (normalize env ctx e2) 
    		    
  let rec infer env ctx e =
    let open Expr in
    match e with
    |CVar x -> Ctx.ty_var ctx x
    |Sub (e,s) ->
      let c1 = (Sub.source s) in Ctx.checkEqual env ctx c1;
      let c2 = (Sub.target s) in
      let ty = infer_ecoh env c2 e in
      let () = checkT env c2 ty in
      (** Useless? *)
      Expr.subst ty s
    |(Obj |Arr _) -> raise (HasNoType (Expr.to_string e true false))
    |PArr _ -> assert (false)
  and infer_ecoh env ctx coh =
    let open Expr in
    match coh with
    |Fold _ -> assert (false) (** No cut rule yet *)
    |Unfold coh ->
      Ctx.checkEqual env ctx (Ctx.of_ps (Coh.ps coh));
      Coh.target coh
  and checkT env ctx e =
    let open Expr in
    match e with
    |Obj -> ()
    |Arr (t,u,v) -> checkT env ctx t; checkType env ctx u t; checkType env ctx v t
    |(CVar _ |Sub _) -> raise (IsNotType (Expr.to_string e true false))
    |PArr _ -> assert (false)
  and checkType env ctx e1 e2  =
    checkEqual env ctx (infer env ctx e1) e2 
end
    
type var = Var.t
type evar = EVar.t
type env = Env.t
type ctx = Ctx.t
type sub = Sub.t
type ps = PS.t
type expr = Expr.t
type coh = Coh.t
	      
let empty_ctx = Ctx.empty ()
let empty_env = Env.empty ()
let mk_ps = PS.mk
let mk_sub = Sub.mk
let mk_coh = Coh.mk 
let add_env = Env.add
let add_ctx = Ctx.add
let in_ctx = Ctx.mem
let expr_to_string = Expr.to_string                  
let coh_to_string = Coh.to_string                  

(** To be removed, for debugging purposes *)
let string_of_ctx = fun x -> Ctx.to_string x false true
