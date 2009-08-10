val texpr_cofactor : (Expr0.t -> 'a -> 'b) -> Expr0.t array -> 'a -> 'b array
val texpr_support :
  ('a, 'b, Cudd.Man.v) Bdd.Cond.t -> Expr0.t array -> Cudd.Man.v Cudd.Bdd.t
val texpr_cofactors :
  ('a, 'b, Cudd.Man.v, 'c) Bdd.Env.t0 ->
  Expr0.t array -> int -> Expr0.t array * Expr0.t array
val split_lvar :
  string list -> Expr0.t list -> string list * Apron.Var.t array
val split_texpr :
  Expr0.t array -> Cudd.Man.v Bdd.Expr0.t list * ApronexprDD.t array
val split_lvarlexpr :
  string list ->
  Expr0.t list ->
  string list * Cudd.Man.v Bdd.Expr0.t list * Apron.Var.t array *
  ApronexprDD.t array
val cofactors :
  'a ApronDD.man -> 'b -> 'b Cond.O.t ->
  'a ApronDD.t -> int -> 'a ApronDD.t * 'a ApronDD.t
val descend_mtbdd :
  'a ApronDD.man -> 'b -> 'b Cond.O.t ->
  ('a ApronDD.t -> Expr0.t array -> 'a ApronDD.t) ->
  'a ApronDD.t -> Expr0.t array -> 'a ApronDD.t
val descend :
  cudd:Cudd.Man.vt ->
  maxdepth:int ->
  nocare:('a -> bool) ->
  cube_of_down:('a -> Cudd.Bdd.vt) ->
  cofactor:('a -> Cudd.Bdd.vt -> 'a) ->
  select:('a -> int) ->
  terminal:(depth:int ->
            newcube:Cudd.Bdd.vt -> cube:Cudd.Bdd.vt -> down:'a -> 'b option) ->
  ite:(depth:int ->
       newcube:Cudd.Bdd.vt ->
       cond:int -> dthen:'b option -> delse:'b option -> 'b option) ->
  down:'a -> 'b option