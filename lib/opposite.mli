open Common

type op_data = int list
val op_data_to_string : op_data -> string

module M (S : StrictnessLv)
  :sig
    open Kernel.M(S)
    open Unchecked_types

    val equiv_op_ps : ps -> op_data -> sub_ps
    val tm : tm -> op_data -> tm
    val coh : Coh.t -> op_data -> Coh.t
  end
