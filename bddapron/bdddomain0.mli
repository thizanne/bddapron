(** Combined Boolean/Numerical domain with lists of BDDs and APRON abstract values *)

type 'a man = {
  apron : 'a Apron.Manager.t;
  mutable bdd_restrict : Cudd.Bdd.vt -> Cudd.Bdd.vt -> Cudd.Bdd.vt;
  mutable expr_restrict : Expr0.t -> Cudd.Bdd.vt -> Expr0.t;
  mutable meet_disjoint : bool;
  mutable join_disjoint : bool;
  mutable meet_cond_unique : bool;
  mutable meet_cond_disjoint : bool;
  mutable meet_cond_depth : int;
  mutable assign_unique : bool;
  mutable assign_disjoint : bool;
  mutable substitute_unique : bool;
  mutable substitute_disjoint : bool;
  mutable forget_unique : bool;
  mutable forget_disjoint : bool; 
  mutable change_environment_unique : bool;
  mutable change_environment_disjoint : bool;
}
  (** BDDAPRON Manager. The type parameter ['a] indicates the
      underlying APRON abstract domain, as in type {!'a
      Apron.Abstract1.t} *)

type 'a elt = (Cudd.Man.v, 'a Apron.Abstract0.t) Bddleaf.elt

type 'a t = {
  mutable list : 'a elt list;
  bottom : 'a elt;
  mutable unique : bool;
  mutable disjoint : bool;
}
  (** Abstract value. *)

val make_man : 'a Apron.Manager.t -> 'a man
  (** Makes a BDDAPRON manager from an APRON manager, and fills
  options with default values *)

val canonicalize : ?apron:bool -> ?unique:bool -> ?disjoint:bool -> 'a man -> 'a t -> unit
  (** Canonicalize an abstract value by ensuring uniqueness and
      disjointness properties. If [apron] is true, then also
      normalize APRON abstract values. By default: [apron=false,
      unique=disjoint=true]. *)

val size : 'a man -> 'a t -> int
val print : Env.t -> Format.formatter -> 'c t -> unit
  (** Printing function *)

(*  ********************************************************************** *)
(** {2 Constructors, accessors, tests and property extraction} *)
(*  ********************************************************************** *)

(*  ====================================================================== *)
(** {3 Basic constructor} *)
(*  ====================================================================== *)

val bottom : 'a man -> Env.t -> 'a t
val top : 'a man -> Env.t -> 'a t
val of_apron : 'a man -> Env.t -> 'a Apron.Abstract0.t -> 'a t

(*  ====================================================================== *)
(** {3 Tests} *)
(*  ====================================================================== *)

val is_bottom : 'a man -> 'a t -> bool
val is_top : 'a man -> 'a t -> bool
val is_leq : 'a man -> 'a t -> 'a t -> bool
val is_eq : 'a man -> 'a t -> 'a t -> bool

(*  ====================================================================== *)
(** {3 Extraction of properties} *)
(*  ====================================================================== *)

val to_bddapron : 'a man -> 'a t -> (Expr0.Bool.t * 'a Apron.Abstract0.t) list

(*  ********************************************************************** *)
(** {2 Operations} *)
(*  ********************************************************************** *)

val meet : 'a man -> 'a t -> 'a t -> 'a t
val join : 'a man -> 'a t -> 'a t -> 'a t
val meet_condition : 'a man -> Env.t -> Cond.t -> 'a t -> Expr0.Bool.t -> 'a t
  
val assign_lexpr :
  ?relational:bool -> ?nodependency:bool ->
  'a man -> Env.t -> Cond.t ->
  'a t -> string list -> Expr0.t list -> 'a t option -> 'a t
val substitute_lexpr :
  'a man -> Env.t -> Cond.t ->
  'a t -> string list -> Expr0.t list -> 'a t option -> 'a t
val forget_list :
  'a man -> Env.t -> 'a t -> string list -> 'a t
val widening : 'a man -> 'a t -> 'a t -> 'a t

(*  ********************************************************************** *)
(** {2 Opened signature and Internal functions} *)
(*  ********************************************************************** *)

module O : sig
  val check_wellformed : 'a man -> 'a t -> bool
  
  val canonicalize : ?apron:bool -> ?unique:bool -> ?disjoint:bool -> 'a man -> 'a t -> unit
  val size : 'a man -> 'a t -> int
  val print : 
    ('a,'b) #Env.O.t ->
    Format.formatter -> 'c t -> unit
  val bottom : 'a man -> ('b,'c) #Env.O.t -> 'a t
  val top : 'a man -> ('b,'c) #Env.O.t -> 'a t
  val of_apron : 'a man -> ('b,'c) #Env.O.t -> 'a Apron.Abstract0.t -> 'a t
  val is_bottom : 'a man -> 'a t -> bool
  val is_top : 'a man -> 'a t -> bool
  val is_leq : 'a man -> 'a t -> 'a t -> bool
  val is_eq : 'a man -> 'a t -> 'a t -> bool
  val to_bddapron : 'a man -> 'a t -> (Cudd.Bdd.vt * 'a Apron.Abstract0.t) list
  val meet : 'a man -> 'a t -> 'a t -> 'a t
  val join : 'a man -> 'a t -> 'a t -> 'a t
  val meet_condition : 'a man -> (('b,'c) #Env.O.t as 'd) -> (Cond.cond,'d) #Cond.O.t -> 'a t -> Expr0.Bool.t -> 'a t

  val assign_lexpr :
    ?relational:bool -> ?nodependency:bool ->
    'a man ->
    (([> Env.typ ], [> Bdd.Env.typdef ]) #Env.O.t as 'b) ->
    (Cond.cond, 'b) #Cond.O.t ->
    'a t -> string list -> Expr0.t list -> 'a t option -> 'a t
  val substitute_lexpr :
    'a man ->
    (([> Env.typ ], [> Bdd.Env.typdef ]) #Env.O.t as 'b) ->
    (Cond.cond, 'b) #Cond.O.t ->
    'a t -> string list -> Expr0.t list -> 'a t option -> 'a t

  val forget_list :
    'a man -> Env.t -> 'a t -> string list -> 'a t
  val widening : 'a man -> 'a t -> 'a t -> 'a t
  val apply_change : 
    bottom:'a Apron.Abstract0.t ->
    'a man -> 'a t -> Env.change -> 'a t
  val apply_permutation :
    'a man -> 'a t -> int array option * Apron.Dim.perm option -> 'a t
end

