open Common

val ctx : (Var.t * Syntax.ty) list -> ctx
val ty : ctx -> Syntax.ty -> ty
val tm : ctx -> Syntax.tm -> tm
val ty_in_ps : (Var.t * Syntax.ty) list -> Syntax.ty -> ty
val ps : (Var.t * Syntax.ty) list -> ps
