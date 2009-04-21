(** Finite-type expressions linked to normalized environments *)

(* This file is part of the FORMULA Library, released under LGPL license.
   Please read the COPYING file packaged in the distribution  *)

open Format
open Env

(*  ********************************************************************** *)
(** {2 Opened signatures and Internal functions} *)
(*  ********************************************************************** *)

module O = struct

  (*  ==================================================================== *)
  (** {3 Internal} *)
  (*  ==================================================================== *)

  let print_env fmt env = Env.O.print Env.print_typ Env.print_typdef fmt env

  let check_var (env:('a,'b,'d) #Env.O.t) (var:string) : unit =
    try
      let typ = env#typ_of_var var in
      let ok =
	match typ with
	| #Enum.typ -> PMappe.mem var env#vartid
	| _ -> true
      in
      if not ok then raise Not_found
    with Not_found ->
      failwith (Format.sprintf "The variable %s is unknown or has a wrong type in the environement of the value" var)

  let check_lvar env (lvar:string list) : unit =
    List.iter (check_var env) lvar

  let mapunop f e =
    make_value e.env (f e.val0)

  let check_value env t =
    if not (
      Env.is_eq env t.env &&
	env#bddindex0 = t.env#bddindex0
    )
    then 
      failwith (Print.sprintf "Bdd.Expr1: value does not have the expected environement@.env=%a@.t.env=%a@." print_env env print_env t.env);
    ()

  let check_value2 t1 t2 = 
    if not (
      Env.is_eq t1.env t2.env &&
	t1.env#bddindex0 = t2.env#bddindex0
    )
    then
      failwith (Print.sprintf "Bdd.Expr1: operation called with non-equal environments:@.env1=%a@.env2=%a@." print_env t1.env print_env t2.env);
    ()

  let mapbinop f t1 t2 =
    check_value2 t1 t2;
    make_value t1.env (f t1.val0 t2.val0)
      
  let mapbinope f t1 t2 =
    check_value2 t1 t2;
    make_value t1.env (f t2.env t1.val0 t2.val0)

  let check_value3 t1 t2 t3 =
    check_value2 t1 t2;
    check_value2 t1 t3

  let mapterop f t1 t2 t3 =
    check_value3 t1 t2 t3;
    make_value t1.env (f t1.val0 t2.val0 t3.val0)
      
  let check_lvarvalue env lvarexpr =
    List.map
      (fun (var,e) ->
	check_var env var;
	check_value env e;
	(var,e.val0)
      )
      lvarexpr

  let check_lvalue env lexpr =
    List.map
      (fun e -> check_value env e; e.val0)
      lexpr
	
  let check_ovalue env = function
    | None -> None
    | Some x -> check_value env x; Some x.val0
	
  (*  ==================================================================== *)
  (** {3 Datatypes} *)
  (*  ==================================================================== *)

  type ('a,'b) t = ('a, 'b Expr0.expr) Env.value
  constraint 'a = ('c,'d,'b) #Env.O.t

  type ('a,'b) expr = ('a,'b) t
    (** Type of general expressions *)

  (*  ==================================================================== *)
  (** {3 Expressions} *)
  (*  ==================================================================== *)

  let typ_of_expr e = Expr0.O.typ_of_expr e.val0

  let extend_environment e nenv =
    Env.extend_environment Expr0.O.permute e nenv

  let ite e1 e2 e3 =
    mapterop Expr0.O.ite e1 e2 e3

  let cofactor e1 e2 = mapbinop Expr0.cofactor e1 e2
  let restrict e1 e2 = mapbinop Expr0.restrict e1 e2
  let tdrestrict e1 e2 = mapbinop Expr0.tdrestrict e1 e2

  let substitute_by_var e lvarvar =
    make_value e.env (Expr0.O.substitute_by_var e.Env.env e.Env.val0 lvarvar)
  let substitute e lvarexpr =
    let lvarexpr = check_lvarvalue e.env lvarexpr in
    make_value e.env (Expr0.O.substitute e.env e.val0 lvarexpr)

  let eq e1 e2 = mapbinope Expr0.O.eq e1 e2

  let support (e:('a,'b) expr) = Expr0.O.support e.env e.val0

  let support_cond (e:('a,'b) expr) = Expr0.O.support_cond e.env e.val0

  let print fmt (e:('a,'b) expr) : unit = Expr0.O.print e.env fmt e.val0

  (*  -------------------------------------------------------------------- *)
  (** {4 Boolean expressions} *)
  (*  -------------------------------------------------------------------- *)

  module Bool = struct
    type ('a,'b) t = ('a, 'b Cudd.Bdd.t) Env.value
    constraint 'a = ('c,'d,'b) #Env.O.t

    let of_expr e : ('a,'b) t =
      match e.val0 with
      | `Bool x -> make_value e.env x
      | _ -> failwith "Bool.of_expr: Boolean expression expected"

    let to_expr (e:('a,'b) t) =
      make_value e.env (`Bool e.val0)

    let extend_environment e nenv = Env.extend_environment Cudd.Bdd.permute e nenv

    let dtrue env = make_value env (Cudd.Bdd.dtrue env#cudd)
    let dfalse env = make_value env (Cudd.Bdd.dfalse env#cudd)
    let of_bool env b = if b then dtrue env else dfalse env

    let var env (var:string) =
      check_var env var;
      make_value env (Expr0.O.Bool.var env var)

    let dnot e = mapunop Cudd.Bdd.dnot e

    let dand e1 e2 = mapbinop Cudd.Bdd.dand e1 e2
    let dor e1 e2 = mapbinop Cudd.Bdd.dor e1 e2
    let xor e1 e2 = mapbinop Cudd.Bdd.xor e1 e2
    let nand e1 e2 = mapbinop Cudd.Bdd.nand e1 e2
    let nor e1 e2 = mapbinop Cudd.Bdd.nor e1 e2
    let nxor e1 e2 = mapbinop Cudd.Bdd.nxor e1 e2
    let eq e1 e2 = mapbinop Cudd.Bdd.eq e1 e2
    let leq e1 e2 = mapbinop (fun x y -> Cudd.Bdd.dor y (Cudd.Bdd.dnot x)) e1 e2
    let ite e1 e2 e3 = mapterop Cudd.Bdd.ite e1 e2 e3

    let is_true e = Cudd.Bdd.is_true e.val0
    let is_false e = Cudd.Bdd.is_false e.val0
    let is_cst e = Cudd.Bdd.is_cst e.val0
    let is_eq e1 e2 = 
      check_value2 e1 e2;
      Cudd.Bdd.is_equal e1.val0 e2.val0

    let is_leq e1 e2 =
      check_value2 e1 e2;
      Cudd.Bdd.is_leq e1.val0 e2.val0
	
    let is_inter_false e1 e2 =
      check_value2 e1 e2;
      Cudd.Bdd.is_inter_empty e1.val0 e2.val0
	
    let exist (lvar:string list) e =
      check_lvar e.env lvar;
      make_value
	e.env
	(Cudd.Bdd.exist (Expr0.O.bddsupport e.env lvar) e.val0)

    let forall (lvar:string list) e =
      check_lvar e.env lvar;
      make_value
	e.env
	(Cudd.Bdd.forall (Expr0.O.bddsupport e.env lvar) e.val0)

    let cofactor e1 e2 = mapbinop Cudd.Bdd.cofactor e1 e2
    let restrict e1 e2 = mapbinop Cudd.Bdd.restrict e1 e2
    let tdrestrict e1 e2 = mapbinop Cudd.Bdd.tdrestrict e1 e2

    let substitute_by_var e lvarvar =
      make_value e.Env.env
	(Expr0.O.Bool.substitute_by_var e.Env.env e.Env.val0 lvarvar)
    let substitute e lvarexpr =
      of_expr (substitute (to_expr e) lvarexpr)

    let print fmt (x:('a,'b) t) =
      Expr0.O.print_bdd x.env fmt x.val0

  end

  (*  -------------------------------------------------------------------- *)
  (** {4 Bounded integer expressions} *)
  (*  -------------------------------------------------------------------- *)

  module Bint = struct
    type ('a,'b) t = ('a, 'b Int.t) Env.value
    constraint 'a = ('c,'d,'b) #Env.O.t

    let of_expr e : ('a,'b) t =
      match e.val0 with
      | `Bint x -> make_value e.env x
      | _ -> failwith "Bint.of_expr: bounded integer expression expected"

    let to_expr (e:('a,'b) t)  =
      make_value e.env (`Bint e.val0)

    let extend_environment e nenv = Env.extend_environment Int.permute e nenv

    let of_int env typ cst =
      match typ with
      | `Tbint(sgn,size) ->
	  make_value env (Int.of_int env#cudd sgn size cst)

    let var env (var:string) =
      make_value env (Expr0.O.Bint.var env var)

    let neg e = mapunop Int.neg e
    let succ e = mapunop Int.succ e
    let pred e = mapunop Int.pred e

    let add e1 e2 = mapbinop Int.add e1 e2
    let sub e1 e2 = mapbinop Int.sub e1 e2
    let mul e1 e2 = mapbinop Int.mul e1 e2
    let shift_left n e = mapunop (Int.shift_left n) e
    let shift_right n e = mapunop (Int.shift_right n) e
    let scale n e = mapunop (Int.scale n) e
    let ite e1 e2 e3 = mapterop Int.ite e1 e2 e3

    let zero e = make_value e.env (Int.zero e.env#cudd e.val0)

    let eq e1 e2 = mapbinop (Int.equal e1.env#cudd) e1 e2
    let supeq e1 e2 = mapbinop (Int.greatereq e1.env#cudd) e1 e2
    let sup e1 e2 = mapbinop (Int.greater e1.env#cudd) e1 e2
    let eq_int e n = make_value e.env (Int.equal_int e.env#cudd e.val0 n)
    let supeq_int e n = make_value e.env (Int.greatereq_int e.env#cudd e.val0 n)

    let cofactor e1 e2 = mapbinop Int.cofactor e1 e2
    let restrict e1 e2 = mapbinop Int.restrict e1 e2
    let tdrestrict e1 e2 = mapbinop Int.tdrestrict e1 e2

    let substitute_by_var e lvarvar =
      make_value e.Env.env
	(Expr0.O.Bint.substitute_by_var e.Env.env e.Env.val0 lvarvar)
    let substitute e lvarexpr =
      of_expr (substitute (to_expr e) lvarexpr)

    let guard_of_int (e:('a,'b) t) (n:int) : ('a,'b) Bool.t =
      make_value e.env (Int.guard_of_int e.env#cudd e.val0 n)

    let guardints (e:('a,'b) t) : (('a,'b) Bool.t*int) list =
      let res = Int.guardints e.env#cudd e.val0 in
      List.map (fun (bdd,n) -> (make_value e.env bdd, n)) res

    let print fmt (x:('a,'b) t) =
      Int.print_minterm (Expr0.O.print_bdd x.env) fmt x.val0

  end

  (*  -------------------------------------------------------------------- *)
  (** {4 Enumerated type expressions} *)
  (*  -------------------------------------------------------------------- *)

  module Benum = struct
    type ('a,'b) t = ('a, 'b Enum.t) Env.value
    constraint 'a = ('c,'d,'b) #Env.O.t

    let of_expr e : ('a,'b) t =
      match e.val0 with
      | `Benum x -> make_value e.env x
      | _ -> failwith "Benum.of_expr: bounded integer expression expected"

    let to_expr (e:('a,'b) t) =
      make_value e.env (`Benum e.val0)

    let extend_environment e nenv = Env.extend_environment Enum.permute e nenv

    let var env (var:string) =
      make_value env (Expr0.O.Benum.var env var)

    let ite e1 e2 e3 = mapterop Enum.ite e1 e2 e3

    let eq e1 e2 = mapbinope Enum.equal e1 e2

    let eq_label e label =
      make_value e.env (Enum.equal_label e.env e.val0 label)

    let cofactor e1 e2 = mapbinop Enum.cofactor e1 e2
    let restrict e1 e2 = mapbinop Enum.restrict e1 e2
    let tdrestrict e1 e2 = mapbinop Enum.tdrestrict e1 e2

    let substitute_by_var e lvarvar =
      make_value e.Env.env
	(Expr0.O.Benum.substitute_by_var e.Env.env e.Env.val0 lvarvar)
    let substitute e lvarexpr =
      of_expr (substitute (to_expr e) lvarexpr)

    let guard_of_label (e:('a,'b) t) (n:string) : ('a,'b) Bool.t =
      make_value e.env (Enum.guard_of_label e.env e.val0 n)

    let guardlabels (e:('a,'b) t) : (('a,'b) Bool.t*string) list =
      let res = Enum.guardlabels e.env e.val0 in
      List.map (fun (bdd,n) -> (make_value e.env bdd, n)) res

    let print fmt (x:('a,'b) t) =
      Enum.print_minterm (Expr0.O.print_bdd x.env) x.env fmt x.val0

  end

  (*  ==================================================================== *)
  (** {3 General expressions} *)
  (*  ==================================================================== *)

  let var env (var:string) : ('a,'b) expr
      =
    make_value env (Expr0.O.var env var)

  let make = make_value

  (*  ====================================================================== *)
  (** {3 List of expressions} *)
  (*  ====================================================================== *)

  module List = struct
    type ('a,'b) t = ('a, 'b Expr0.t list) Env.value
    constraint 'a = ('c,'d,'b) #Env.O.t
      
    let of_lexpr0 = make_value
    let of_lexpr env lexpr1 =
      let lexpr0 = check_lvalue env lexpr1 in
      of_lexpr0 env lexpr0
    let extend_environment e nenv =
      Env.extend_environment
	(fun lexpr0 perm ->
	  (List.map (fun e -> Expr0.O.permute e perm) lexpr0))
	e nenv

    let print ?first ?sep ?last fmt x =
      Print.list ?first ?sep ?last
	(Expr0.O.print x.env) fmt x.val0 
  end
    
end

(*  ********************************************************************** *)
(** {2 Closed signatures} *)
(*  ********************************************************************** *)

(*  ====================================================================== *)
(** {3 Expressions} *)
(*  ====================================================================== *)

type 'a t = ('a Env.t, 'a Expr0.expr) Env.value

type 'a expr = 'a t

let typ_of_expr = O.typ_of_expr
let make = O.make
let extend_environment = O.extend_environment
let var = O.var
let ite = O.ite
let eq = O.eq
let substitute_by_var = O.substitute_by_var
let substitute = O.substitute
let support = O.support
let support_cond = O.support_cond
let cofactor = O.cofactor
let restrict = O.restrict
let tdrestrict = O.tdrestrict
let print = O.print

module Bool = struct
  type 'a t = ('a Env.t, 'a Cudd.Bdd.t) Env.value
  let of_expr = O.Bool.of_expr
  let to_expr = O.Bool.to_expr
  let extend_environment = O.Bool.extend_environment
  let dtrue = O.Bool.dtrue
  let dfalse = O.Bool.dfalse
  let of_bool = O.Bool.of_bool
  let var = O.Bool.var
  let dnot = O.Bool.dnot
  let dand = O.Bool.dand
  let dor = O.Bool.dor
  let xor = O.Bool.xor
  let nand = O.Bool.nand
  let nor = O.Bool.nor
  let nxor = O.Bool.nxor
  let eq = O.Bool.eq
  let leq = O.Bool.leq
  let ite = O.Bool.ite
  let is_true = O.Bool.is_true
  let is_false = O.Bool.is_false
  let is_cst = O.Bool.is_cst
  let is_eq = O.Bool.is_eq
  let is_leq = O.Bool.is_leq
  let is_inter_false = O.Bool.is_inter_false
  let exist = O.Bool.exist
  let forall = O.Bool.forall
  let cofactor = O.Bool.cofactor
  let restrict = O.Bool.restrict
  let tdrestrict = O.Bool.tdrestrict
  let substitute_by_var = O.Bool.substitute_by_var
  let substitute = O.Bool.substitute
  let print = O.Bool.print
end
module Bint = struct
  type 'a t = ('a Env.t, 'a Int.t) Env.value
  let of_expr = O.Bint.of_expr
  let to_expr = O.Bint.to_expr
  let extend_environment = O.Bint.extend_environment
  let of_int = O.Bint.of_int
  let var = O.Bint.var
  let neg = O.Bint.neg
  let succ = O.Bint.succ
  let pred = O.Bint.pred
  let add = O.Bint.add
  let sub = O.Bint.sub
  let mul = O.Bint.mul
  let shift_left = O.Bint.shift_left
  let shift_right = O.Bint.shift_right
  let scale = O.Bint.scale
  let ite = O.Bint.ite
  let zero = O.Bint.zero
  let eq = O.Bint.eq
  let supeq = O.Bint.supeq
  let sup = O.Bint.sup
  let eq_int = O.Bint.eq_int
  let supeq_int = O.Bint.supeq_int
  let cofactor = O.Bint.cofactor
  let restrict = O.Bint.restrict
  let tdrestrict = O.Bint.tdrestrict
  let substitute_by_var = O.Bint.substitute_by_var
  let substitute = O.Bint.substitute
  let guard_of_int= O.Bint.guard_of_int
  let guardints= O.Bint.guardints
  let print = O.Bint.print
end
module Benum = struct
  type 'a t = ('a Env.t, 'a Enum.t) Env.value
  let of_expr = O.Benum.of_expr
  let to_expr = O.Benum.to_expr
  let extend_environment = O.Benum.extend_environment
  let var = O.Benum.var
  let ite = O.Benum.ite
  let eq = O.Benum.eq
  let eq_label = O.Benum.eq_label
  let cofactor = O.Benum.cofactor
  let restrict = O.Benum.restrict
  let tdrestrict = O.Benum.tdrestrict
  let substitute_by_var = O.Benum.substitute_by_var
  let substitute = O.Benum.substitute
  let guard_of_label = O.Benum.guard_of_label
  let guardlabels = O.Benum.guardlabels
  let print = O.Benum.print
end
module List = struct
  type 'a t = ('a Env.t, 'a Expr0.t list) Env.value
    
  let of_lexpr0 = O.List.of_lexpr0
  let of_lexpr = O.List.of_lexpr
  let extend_environment = O.List.extend_environment
  let print = O.List.print
end
