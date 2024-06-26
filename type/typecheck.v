From RDST Require Import type.unscoped type.local type.beta.
Require Import String List Datatypes Lia Relations.
Import ListNotations.
Local Open Scope string_scope.
Local Open Scope list_scope.
Require Import Setoid Morphisms Coq.Program.Basics.
From mathcomp Require Import ssreflect.seq.

Fixpoint lookup (c: (list (nat*local))) (m: nat): option local :=
  match c with
    | (pair n s1) :: xs => if Nat.eqb n m then Some s1 else lookup xs m
    |  nil              => None
  end.

Print process.

Inductive propcont: local -> Prop :=
  | prc_inact: propcont ltinact
  | prc_send : forall p l s c, propcont c -> propcont (ltsend p l s c)
  | prc_recv : forall p C, List.Forall (fun u => propcont u) (map snd C) -> 
                           propcont (ltreceive p C).

Inductive typecont: local -> Prop :=
  | tyc_end   : typecont ltend
  | tyc_send  : forall p l s c, typecont c -> typecont (ltselect p l s c)
  | tyc_branch: forall p C, List.Forall (fun u => typecont u) (map snd C) -> 
                            typecont (ltbranch p C).

(* incomplete set of rules *)
Inductive typeCheck: list (fin*local) -> fin -> local -> local -> Prop :=
  | tc_inact : forall m c, typeCheck c m (ltinact) (ltend)
  | tc_end   : forall m c, typeCheck c m ltend ltstar
  | tc_var   : forall m c s t, Some t = lookup c s ->
                              typeCheck c m (ltvar s) t
  | tc_lambda: forall c p k e t' n m, typeCheck c m p ltstar ->
                                      let t := betan n k (mkproc p gnil) in
                                      (* ctx ext *)
                                      typeCheck ((m, (@body t)) :: c) (S m) e t' ->
                                      typeCheck c m (ltlambda e p) (ltpi (@body t) t')
  | tc_pair  : forall c p k e t' n m, typeCheck c m p ltstar ->
                                      let t := betan n k (mkproc p gnil) in
                                      (* ctx ext *)
                                      typeCheck ((m, (@body t)) :: c) (S m) e t' ->
                                      typeCheck c m (ltpair e p) (ltsig (@body t) t') 
  | tc_mu    : forall m c p t, typeCheck ((m, t) :: c) (S m) p t ->
                               typeCheck c m (ltmu p t) t
  | tc_nval  : forall c m n, typeCheck c m (ltnval n) ltnat
  | tc_bval  : forall c m b, typeCheck c m (ltbval b) ltbool
  | tc_star  : forall c m, typeCheck c m ltstar ltstar
  | tc_nat   : forall c m, typeCheck c m ltnat ltstar
  | tc_bool  : forall c m, typeCheck c m ltbool ltstar
  | tc_add   : forall c e1 e2 m, typeCheck c m e1 ltnat ->
                                 typeCheck c m e2 ltnat ->
                                 typeCheck c m (ltadd e1 e2) ltnat
  | tc_mult  : forall c e1 e2 m, typeCheck c m e1 ltnat ->
                                 typeCheck c m e2 ltnat ->
                                 typeCheck c m (ltmult e1 e2) ltnat
  | tc_subtr : forall c e1 e2 m, typeCheck c m e1 ltnat ->
                                 typeCheck c m e2 ltnat ->
                                 typeCheck c m (ltsubtr e1 e2) ltnat
  | tc_ite   : forall c e1 e2 e3 t m, typeCheck c m e1 ltbool ->
                                      typeCheck c m e2 t ->
                                      typeCheck c m e3 t ->
                                      typeCheck c m (ltite e1 e2 e3) t
  | tc_gt    : forall c e1 e2 m, typeCheck c m e1 ltnat ->
                                 typeCheck c m e2 ltnat ->
                                 typeCheck c m (ltgt e1 e2) ltbool
  | tc_app   : forall c k e e' t t' n m, typeCheck c m e (ltpi t t') ->
                                         typeCheck c m e' t ->
                                         let tt := subst_local (e' .: ltvar) t' in
                                         let t'' := betan n k (mkproc tt gnil) in
                                         typeCheck c m (ltapp e e') (@body t'')
  | tc_pi    : forall c k p p' (t: local) n m, typeCheck c m p ltstar ->
                                               let t := betan n k (mkproc p gnil) in
                                               (* ctx ext *)
                                               typeCheck ((m, (@body t)) :: c) (S m) p' ltstar ->
                                               typeCheck c m (ltpi p' p) ltstar
  | tc_sig   : forall c k p p' (t: local) n m, typeCheck c m p ltstar ->
                                               let t := betan n k (mkproc p gnil) in
                                               (* ctx ext *)
                                               typeCheck ((m, (@body t)) :: c) (S m) p' ltstar ->
                                               typeCheck c m (ltsig p' p) ltstar
  | tc_send  : forall m c p l e P S T, propcont P ->
                                       typeCheck c m e S ->
                                       typeCheck c m P T ->
                                       typeCheck c m (ltsend p l e P) (ltselect p l S T)
  | tc_recv  : forall m c p L (ST P T: list local),
                      List.Forall (fun u => propcont u) P -> 
                      length L = length ST ->
                      length ST = length P ->
                      length P = length T ->
                      (* ctx ext *)
                      List.Forall (fun u => typeCheck ((m, (fst u)) :: c) (S m) (fst (snd u)) (snd (snd u))) (zip ST (zip P T)) ->
                      typeCheck c m (ltreceive p (zip (zip L P) ST)) (ltbranch p (zip (zip L T) ST))
  | tc_branch: forall m c k p L (ST T: list local) n,
                      List.Forall (fun u => typecont u) T -> 
                      length L  = length ST ->
                      length ST = length T ->
                      List.Forall (fun u => typeCheck c m u ltstar) ST ->
                      let ST' := betanList n k (mkprocL ST) in
                      let ST'' := map (@body) ST' in
                      (* ctx ext *)
                      List.Forall (fun u => typeCheck ((m, (fst u)) :: c) (S m) (snd u) ltstar) (zip ST'' T) ->
                      typeCheck c m (ltbranch p (zip (zip L T) ST)) ltstar
  | tc_select: forall m c k p l ST T n,
                      typecont T ->
                      let ST' := betan n k (mkproc ST gnil) in
                      (* ctx ext *)
                      typeCheck ((m, (@body ST')) :: c) (S m) T ltstar ->
                      typeCheck c m (ltselect p l ST T) ltstar.


