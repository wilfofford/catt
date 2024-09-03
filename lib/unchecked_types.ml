open Common

module type Unchecked_types_sig = functor
  (Coh : sig
     type t
   end)
  -> sig
  type ty = Meta_ty of int | Obj | Arr of ty * tm * tm
  and tm = Var of Var.t | Meta_tm of int | Coh of Coh.t * sub_ps
  and sub_ps = (tm * bool) list

  type ctx = (Var.t * (ty * bool)) list
  type sub = { vars : Var.t list; tbl : (Var.t, tm) Hashtbl.t }
  type meta_ctx = (int * ty) list
end

module Unchecked_types (Coh : sig
  type t
end) =
struct
  type ty = Meta_ty of int | Obj | Arr of ty * tm * tm
  and tm = Var of Var.t | Meta_tm of int | Coh of Coh.t * sub_ps
  and sub_ps = (tm * bool) list

  type ctx = (Var.t * (ty * bool)) list
  type sub = { vars : Var.t list; tbl : (Var.t, tm) Hashtbl.t }
  type meta_ctx = (int * ty) list
end
