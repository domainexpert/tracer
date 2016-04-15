(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2011                                               *)
(*    CEA   (Commissariat � l'�nergie atomique et aux �nergies            *)
(*           alternatives)                                                *)
(*    INRIA (Institut National de Recherche en Informatique et en         *)
(*           Automatique)                                                 *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version v2.1                *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(** *)

open Cil_types


(** Node.t is the type of the PDG vertex.
    [compare] and [pretty] are needed by [Abstract_interp.Make_Lattice_Set]. *)
module Node = struct

  type key = PdgIndex.Key.t

  type tt = { id : int; key : key }

  module Counter =
    State_builder.Counter(struct let name = "PdgTypes.Node.Counter" end)

  let make key =
    {id = Counter.next ();
     key = key}

  let key e = e.key
  let print_id fmt e = Format.fprintf fmt "%d" e.id

  let elem_id n = n.id
  let elem_key n = key n
  let stmt n = PdgIndex.Key.stmt n.key

  (* BY: not sure it is a good idea to use (=) on keys, which contain
     Cil structures. Disabled for now
  (** tells if the node represent the same thing that the given key. *)
  let equivalent n key = (elem_key n) = key
  *)

  let print_id fmt n = 
    Format.fprintf fmt "n:%a" print_id n

  include Datatype.Make_with_collections
    (struct
        type t = tt
        let name = "PdgTypes.Elem"
        let reprs = [ { id = -1; key = PdgIndex.Key.top_input } ]
        let structural_descr = Structural_descr.t_record
          [| Structural_descr.p_int; PdgIndex.Key.packed_descr |]
        let compare e1 e2 = Datatype.Int.compare e1.id e2.id
        let hash e = e.id
        let equal e1 e2 = e1.id = e2.id
        let pretty = print_id
        let rehash = Datatype.identity
        let copy = Datatype.undefined
        let internal_pretty_code = Datatype.undefined
        let varname = Datatype.undefined
        let mem_project = Datatype.never_any_project
     end)

  let pretty_list fmt l =
    List.iter (fun n -> Format.fprintf fmt " %a" pretty n) l

  let pretty_with_part fmt (n, z_part) =
    Format.fprintf fmt "%a" pretty n;
    match z_part with None -> ()
      | Some z -> Format.fprintf fmt "(restrict to @[<h 1>%a@])"
                    Locations.Zone.pretty z

  let pretty_node fmt n =
    Format.fprintf fmt "[Elem] %d : %a" (elem_id n)
      PdgIndex.Key.pretty (elem_key n)

  let pretty_nodes fmt nodes =
    let pretty_node n = Format.fprintf fmt "%a@." pretty_node n in
    List.iter pretty_node nodes

end

module NodeSet = Hptset.Make(struct include Node let id = elem_id end)
                   (struct let v = [ [ ] ] end)
                   (struct let l = [ Ast.self ] end)

(** set of nodes of the graph *)
module NodeSetLattice = struct
  include Abstract_interp.Make_Lattice_Set(Node)
  type t_elt = O.elt
  let tag = hash
  let default _v _a _b : t = empty
  let defaultall _v : t = empty
end

module LocInfo = Lmap_bitwise.Make_bitwise (NodeSetLattice)


(** Edges label for the Program Dependence Graph.
  *)
module Dpd : sig
  include Datatype.S

  (** used to speak about the different kinds of dependencies *)
  type td =  Ctrl | Addr | Data

  val make : ?a:bool -> ?d:bool -> ?c:bool -> unit -> t
  val make_simple : td -> t
  val bottom : t
  val top : t

  (** = bottom but needed to build the Graph *)
  val default : t

  val adc_value : t -> bool * bool * bool
  val is_addr : t -> bool
  val is_ctrl : t -> bool
  val is_data : t -> bool
  val is_dpd : td -> t -> bool
  val is_bottom : t -> bool


  val is_included : t -> t -> bool
  val combine : t -> t -> t
  val add : t -> td -> t
  val inter : t -> t -> t
  val intersect : t -> t -> bool

  (** remove the flags that are in m2 for m1 *)
  val minus : t -> t -> t

  val pretty_td : Format.formatter -> td -> unit
  val pretty : Format.formatter -> t -> unit
  end
  =
struct

  type td = Ctrl | Addr | Data

  let pretty_td fmt td = 
    Format.fprintf fmt "%s"
      (match td with Ctrl -> "c" | Addr -> "a" | Data -> "d")

  include Datatype.Int (* Encoding:  %b addr; %b data; %b control *)
  let maddr = 0x100
  let mdata = 0x010
  let mctrl = 0x001

  let make ?(a=false) ?(d=false) ?(c=false) _ =
    match a,d,c with
      | false, false, false -> 0x000
      | true,  false, false -> 0x100
      | false, true,  false -> 0x010
      | false, false, true  -> 0x001
      | true,  true,  false -> 0x110
      | true,  false, true  -> 0x101
      | false, true,  true  -> 0x011
      | true,  true,  true  -> 0x111

  let bottom = 0x000
  let top = 0x111
  let default = bottom

  let is_addr d = (d land maddr) != 0
  let is_ctrl d = (d land mctrl) != 0
  let is_data d = (d land mdata) != 0
  let is_dpd tdpd d = match tdpd with
    | Addr -> is_addr d
    | Ctrl -> is_ctrl d
    | Data -> is_data d

  let is_bottom = (=) bottom

  let adc_value d = (is_addr d, is_data d, is_ctrl d)

  let combine d1 d2 = d1 lor d2
  let inter d1 d2 = d1 land d2
  let intersect d1 d2 = inter d1 d2 != 0
  let is_included d1 d2 = combine d1 d2 = d2

  let make_simple kind = match kind with
    | Ctrl -> mctrl
    | Addr -> maddr
    | Data -> mdata

  let add d kind = combine d (make_simple kind)

  let minus adc1 adc2 = adc1 land (lnot adc2)

  let pretty fmt d =  Format.fprintf fmt "[%c%c%c]"
                        (if is_addr d then 'a' else '-')
                        (if is_ctrl d then 'c' else '-')
                        (if is_data d then 'd' else '-')

end

module DpdZone : sig
  include Datatype.S

  val is_dpd : Dpd.td -> t -> bool
  val make : Dpd.td -> Locations.Zone.t option -> t
  val add : t -> Dpd.td -> Locations.Zone.t option -> t
  val kind_and_zone : t -> Dpd.t * Locations.Zone.t option
  val dpd_zone : t -> Locations.Zone.t option

  val default : t
  val pretty : Format.formatter -> t -> unit

  val tag: t -> int
end = struct

  include Datatype.Pair(Dpd)(Datatype.Option(Locations.Zone))
    (* None == Locations.Zone.Top *)

  let dpd_kind dpd = fst dpd
  let dpd_zone dpd = snd dpd
  let kind_and_zone dpd = dpd
  let make k z = (Dpd.make_simple k), z

  let default = Dpd.default, None

  let is_dpd k dpd = Dpd.is_dpd k (dpd_kind dpd)

  let add ((d1,z1) as dpd) k z =
    let d = Dpd.add d1 k in
    let z = match z1, z with
      | None, _ -> z1
      | _, None -> z
      | Some zz1, Some zz2  ->
          (* we are losing some precision here because for instance :
           * (zz1, addr) + (zz2, data) = (zz1 U zz2, data+addr) *)
          let zz = Locations.Zone.join zz1 zz2 in
            match zz with
              | Locations.Zone.Top(_p, _o) -> None
              | _ -> (* To share values as much as possible *)
                  if (zz == zz1)      then z1
                  else if (zz == zz2) then z
                  else Some zz
    in if (d == d1) && (z == z1) then dpd else d, z

  let pretty fmt dpd =
    Dpd.pretty fmt (dpd_kind dpd);
    match (dpd_zone dpd) with None -> ()
      | Some z ->
          Format.fprintf fmt "@[<h 1>(%a)@]" Locations.Zone.pretty z

  let tag = hash
end

(** The graph itself. *)
module G = struct

  (* Hashtbl to maps of nodes to dpdzone. Used to encode one-directional graphs
     whoses nodes are Node.t, and labels on edges are DpdZone. *)
  module V = struct include Node let id = elem_id end
  module E = struct
    type t = Node.t * DpdZone.t * Node.t
    type label = DpdZone.t
    let src (n, _, _) = n
    let dst (_, _, n) = n
    let label (_, l, _) = l
  end

  module To = Hptmap.Make(V)(DpdZone)(Hptmap.Comp_unused)
    (struct let v = [[]] end)(struct let l = [Ast.self] end)

  module OneDir = Node.Hashtbl.Make(To)

  let add_node_one_dir g v =
    if not (Node.Hashtbl.mem g v) then
      Node.Hashtbl.add g v To.empty

  let add_edge_one_dir g vsrc vdst lbl =
    let cur = try Node.Hashtbl.find g vsrc with Not_found -> To.empty in
    let cur = To.add vdst lbl cur in
    Node.Hashtbl.replace g vsrc cur

  let remove_edge_one_dir g vsrc vdst =
    try
      let cur = Node.Hashtbl.find g vsrc in
      let cur = To.remove vdst cur in
      Node.Hashtbl.replace g vsrc cur
    with Not_found -> ()

  let aux_iter_one_dir ?(rev=false) f v =
    To.iter (fun v' lbl -> f (if rev then (v', lbl, v) else (v, lbl, v' : E.t)))
  let iter_e_one_dir ?(rev=false) f g v =
    let to_ = Node.Hashtbl.find g v in
    aux_iter_one_dir ~rev f v to_

  let fold_e_one_dir ?(rev=false) f g v =
    let to_ = Node.Hashtbl.find g v in
    To.fold (fun v' lbl acc ->
      f (if rev then (v', lbl, v) else (v, lbl, v' : E.t)) acc) to_

  let fold_one_dir f g v =
    let to_ = Node.Hashtbl.find g v in
    To.fold (fun v' _ acc -> f v' acc) to_

  (* Bi-directional graphs *)

  type g = {
    d_graph: OneDir.t;
    co_graph: OneDir.t;
  }

  include Datatype.Make
  (struct
    include Datatype.Undefined
    type t = g
    let name = "PdgTypes.G"
    let reprs = [ let h = Node.Hashtbl.create 0 in
                  { d_graph = h; co_graph = h} ]
    let mem_project = Datatype.never_any_project
    let rehash = Datatype.identity
    open Structural_descr
    let structural_descr =
      t_record [| OneDir.packed_descr; OneDir.packed_descr;|]
   end)

  let add_node g v =
    add_node_one_dir g.d_graph v;
    add_node_one_dir g.co_graph v;
  ;;
  let add_vertex = add_node

  let add_edge g vsrc lbl vdst =
    add_edge_one_dir  g.d_graph vsrc vdst lbl;
    add_edge_one_dir g.co_graph vdst vsrc lbl;
  ;;

  let remove_edge g vsrc vdst =
    remove_edge_one_dir  g.d_graph vsrc vdst;
    remove_edge_one_dir g.co_graph vdst vsrc;
  ;;

  let find_edge g v1 v2 =
    let dsts = Node.Hashtbl.find g.d_graph v1 in
    To.find v2 dsts
  ;;

  let iter_vertex f g = Node.Hashtbl.iter (fun v _ -> f v) g.d_graph
  let iter_edges_e f g =
    Node.Hashtbl.iter (fun v _to -> aux_iter_one_dir f v _to) g.d_graph

  let iter_succ_e f g = iter_e_one_dir           f  g.d_graph
  let fold_succ   f g = fold_one_dir             f  g.d_graph
  let fold_pred   f g = fold_one_dir             f g.co_graph
  let fold_succ_e f g = fold_e_one_dir           f  g.d_graph
  let fold_pred_e f g = fold_e_one_dir ~rev:true f g.co_graph
  let iter_pred_e f g = iter_e_one_dir ~rev:true f g.co_graph

  let succ g v = fold_succ (fun n l -> n :: l) g v []
  let pred g v = fold_pred (fun n l -> n :: l) g v []

  let create () =
    { d_graph = Node.Hashtbl.create 17;
      co_graph = Node.Hashtbl.create 17; }

  let find_dpd g v1 v2 =
    let lbl = find_edge g v1 v2 in
    ((v1, lbl, v2), lbl)

  let add_elem g key =
    let elem = Node.make key in
    add_vertex g elem;
    elem

  let simple_add_dpd g v1 dpd v2 =
    add_edge g v1 dpd v2

  let replace_dpd g (v1, _, v2) new_dpd =
    remove_edge g v1 v2;
    simple_add_dpd g v1 new_dpd v2

  let add_dpd graph v1 dpd_kind opt_zone v2 =
    try
      let edge, old_dpd = find_dpd graph v1 v2 in
      let new_dpd = DpdZone.add old_dpd dpd_kind opt_zone in
      if not (DpdZone.equal old_dpd new_dpd) then
        replace_dpd graph edge new_dpd
    with Not_found ->
      let new_dpd = DpdZone.make dpd_kind opt_zone in
      simple_add_dpd graph v1 new_dpd v2

  let edge_dpd (_, lbl, _) = DpdZone.kind_and_zone lbl
  let pretty_edge_label = DpdZone.pretty

end

(** DataState is associated with a program point
    and provide the dependancies for the data,
    ie. it stores for each location the nodes of the pdg where its value
    was last defined.
    Managed in src/pdg/state.ml
  *)
type t_data_state =
  { loc_info : LocInfo.t ; under_outputs : Locations.Zone.t }

module Data_state =
  Datatype.Make
    (struct
      include Datatype.Serializable_undefined
      type t = t_data_state
      let name = "PdgTypes.Data_state"
      let reprs =
        List.fold_left
          (fun acc l ->
            List.fold_left
              (fun acc z -> { loc_info = l; under_outputs = z } :: acc)
              acc
              Locations.Zone.reprs)
          []
          LocInfo.reprs
      let rehash = Datatype.identity
      let structural_descr =
        Structural_descr.t_record
          [| LocInfo.packed_descr; Locations.Zone.packed_descr |]
      let mem_project = Datatype.never_any_project
     end)


(** PDG for a function *)
module Pdg = struct
  exception Top
  exception Bottom

  type t_fi = (Node.t, unit) PdgIndex.FctIndex.t
  (** The nodes which are associated the each element.
      There is only one node for simple statements,
      but there are several for a call for instance. *)
  let t_fi_descr =
    PdgIndex.FctIndex.t_descr ~ni:(Descr.str Node.descr) ~ci:Structural_descr.t_unit


  type t_def = {
    graph : G.t ;
    states : t_data_state Inthash.t ;
    index : t_fi ;
  }

  type t_body = PdgDef of t_def | PdgTop | PdgBottom

  module Body_datatype =
    Datatype.Make
      (struct
        include Datatype.Undefined(*Serializable_undefined*)
        type t = t_body
        let reprs = [ PdgTop; PdgBottom ]
        let rehash = Datatype.identity
        open Structural_descr
        let structural_descr =
          Structure
            (Sum [| [|
              pack
                (t_record [|
                   G.packed_descr;
                   (let module H = Cil_datatype.Int_hashtbl.Make(Data_state) in
                    H.packed_descr);
                   pack t_fi_descr;
                 |])
            |] |])

        let name = "t_body"
        let mem_project = Datatype.never_any_project
       end)
  let () = Type.set_ml_name Body_datatype.ty None

  include Datatype.Pair(Kernel_function)(Body_datatype)

  let make kf graph states index =
    let body = { graph = graph; states = states; index = index ; } in
      (kf, PdgDef body)

  let top kf = (kf, PdgTop)
  let bottom kf = (kf, PdgBottom)

  let is_top pdg = match snd pdg with PdgTop -> true | _ -> false
  let is_bottom pdg = match snd pdg with PdgBottom -> true | _ -> false

  let get_pdg_body pdg = match snd pdg with
    | PdgDef pdg -> pdg
    | PdgTop -> raise Top
    | PdgBottom -> raise Bottom

  let get_kf pdg = fst pdg
  let get_graph pdg = let pdg = get_pdg_body pdg in  pdg.graph
  let get_states pdg = let pdg = get_pdg_body pdg in  pdg.states
  let get_index pdg = let pdg = get_pdg_body pdg in  pdg.index

  let iter_nodes f pdg = G.iter_vertex f (get_graph pdg)

  let fold_call_nodes f acc pdg call =
    let _, call_pdg = PdgIndex.FctIndex.find_call (get_index pdg) call in
    let do_it acc (_k, n) = f acc n in
      PdgIndex.Signature.fold do_it acc call_pdg

  type dpd_info = (Node.t * Locations.Zone.t option)

  (** gives the list of nodes that depend to the given node
      with a given kind of dependency.
    *)
  let get_x_direct_edges ~co dpd_type_opt pdg node =
    let pdg = get_pdg_body pdg in
    let is_dpd_ok e = match dpd_type_opt with None -> true
      | Some k -> DpdZone.is_dpd k (G.E.label e)
    in
    let filter edge nodes =
      if is_dpd_ok edge then edge :: nodes else nodes
    in
    let fold = if co then G.fold_pred_e else G.fold_succ_e  in
    let nodes = fold filter pdg.graph node [] in
      nodes

  let edge_end co = if co then G.E.src else G.E.dst

  let get_x_direct ~co dpd_type pdg node =
    let edges = get_x_direct_edges ~co (Some dpd_type) pdg node in
    List.map
      (fun e -> (edge_end co e, DpdZone.dpd_zone (G.E.label e)))
      edges

  let get_x_direct_dpds k = get_x_direct ~co:false k
  let get_x_direct_codpds k = get_x_direct ~co:true k

  let get_all_direct ~co pdg node =
    let edges = get_x_direct_edges ~co None pdg node in
    List.map
      (fun e -> (edge_end co e, DpdZone.dpd_zone (G.E.label e)))
      edges

  let get_all_direct_dpds pdg node = get_all_direct ~co:false pdg node
  let get_all_direct_codpds pdg node = get_all_direct ~co:true pdg node

  let get_all_direct_edges pdg node =
    let co = false in
    let edges = get_x_direct_edges ~co None pdg node in
    let get_info e =
      let k, z = G.edge_dpd e in
      let n = edge_end co e in
        (k, z, n)
    in
      List.map get_info edges

  let pretty_graph ?(bw=false) fmt graph =
    let all = (* Sorted print is nicer for the user *)
      let r = ref [] in
      G.iter_vertex (fun n -> r := n :: !r) graph;
      List.sort Node.compare !r
    in
    let iter = if bw then G.iter_pred_e else G.iter_succ_e in
    let print_node n =  Format.fprintf fmt "%a@." Node.pretty_node n in
    let print_dpd d =
      let dpd_kind = G.E.label d in
      if bw then Format.fprintf fmt "  <-%a- %d@." G.pretty_edge_label dpd_kind
        (Node.elem_id (G.E.src d))
      else Format.fprintf fmt "  -%a-> %d@." G.pretty_edge_label dpd_kind
        (Node.elem_id (G.E.dst d))
    in
    let print_node_and_dpds n =
      print_node n;
      iter print_dpd graph n
    in
    List.iter print_node_and_dpds all

  let pretty_bw ?(bw=false) fmt pdg =
    try
      let graph = get_graph pdg in
      pretty_graph ~bw fmt graph;
    with
    | Top -> Format.fprintf fmt "Top PDG@."
    | Bottom -> Format.fprintf fmt "Bottom PDG@."



  (*-----------------------------------------------------------------------*)
  module Printer = struct

    type parent_t = t
    type t = parent_t
    module V = G.V
    module E = struct
      type t = G.E.t * bool (** boolean to say that the edge is dynamic *)
      let src (e, _dyn) = G.E.src e
      let dst (e, _dyn) = G.E.dst e
    end

    let iter_vertex f pdg =
      try
        let graph = get_graph pdg in
        G.iter_vertex f graph
      with Top | Bottom -> ()

    let iter_edges_e f pdg =
      try
        let graph = get_graph pdg in
        let f_static e = f (e, false) in
        G.iter_edges_e f_static graph;
      with Top | Bottom -> ()

    let graph_attributes _ = [`Rankdir `TopToBottom ]

    let default_vertex_attributes _ = [`Style `Filled]
    let vertex_name v = string_of_int (Node.elem_id v)

    let vertex_attributes v =
      let color_in = (`Fillcolor 0x6495ED) in
      let color_out = (`Fillcolor 0x90EE90) in
      let color_decl = (`Fillcolor 0xFFEFD5) in
      let color_stmt = (`Fillcolor 0xCCCCCC) in
    (* let color_annot = (`Fillcolor 0x999999) in *)
      let color_call = (`Fillcolor 0xFF8A0F) in
      let color_elem_call = (`Fillcolor 0xFFCA6E) in
      let sh_box = (`Shape `Box) in
      let key = Node.elem_key v in
      let sh, col, txt = match key with
        | PdgIndex.Key.VarDecl v ->
          let txt =
            Pretty_utils.sfprintf "@[Decl %a@]" !Ast_printer.d_ident v.vname
          in
          (`Shape `Box) , color_decl , txt
        | PdgIndex.Key.SigKey k ->
          let txt = Pretty_utils.sfprintf "%a"
            PdgIndex.Signature.pretty_key k
          in
          let color = match k with | PdgIndex.Signature.Out _ -> color_out | _ ->  color_in in
          (`Shape `Box), color, txt
        | PdgIndex.Key.Stmt s ->
          let sh, txt = match s.skind with
            | Switch (exp,_,_,_) | If (exp,_,_,_) ->
              let txt = Pretty_utils.sfprintf "%a" !Ast_printer.d_exp exp in
              (`Shape `Diamond), txt
            | Loop _ ->
              (`Shape `Doublecircle), "while"
            | Block _ | UnspecifiedSequence _ ->
              (`Shape `Doublecircle), "{}"
            | Goto _ | Break _ | Continue _ ->
              let txt = Pretty_utils.sfprintf "%a"
                (Cil.defaultCilPrinter#pStmtKind s) s.skind
              in (`Shape `Doublecircle), txt
            | Return _ | Instr _ ->
              let txt = Pretty_utils.sfprintf "%a"
                (Cil.defaultCilPrinter#pStmtKind s) s.skind in
              sh_box, txt
            | _ -> sh_box, "???"
          in sh, color_stmt, txt
        | PdgIndex.Key.CallStmt call ->
          let call_stmt = PdgIndex.Key.call_from_id call in
          let txt = Pretty_utils.sfprintf "%a"
            (Cil.defaultCilPrinter#pStmtKind call_stmt)
            call_stmt.skind
          in sh_box, color_call, txt
        | PdgIndex.Key.SigCallKey (_call, sgn) ->
          let txt =
            Pretty_utils.sfprintf "%a" PdgIndex.Signature.pretty_key sgn
          in
          sh_box, color_elem_call, txt
        | PdgIndex.Key.Label _ ->
          let txt = Pretty_utils.sfprintf "%a" PdgIndex.Key.pretty key in
          sh_box, color_stmt, txt
      in sh :: col :: [`Label ( String.escaped txt)]

    let default_edge_attributes _ = []

    let edge_attributes (e, dynamic) =
      let d, z = G.edge_dpd e in
      let attrib = [] in
      let attrib = match z with
        | None -> attrib
        | Some z ->
          let txt =
            Pretty_utils.sfprintf "@[<h 1>%a@]" Locations.Zone.pretty z in
          (`Label txt) :: attrib
      in
      let attrib =
        let color =
          if Dpd.is_data d then (if dynamic then 0xFF00FF else 0x0000FF)
          else  (if dynamic then 0xFF0000 else 0x000000)
        in (`Color color) :: attrib
      in
      let attrib =
        if Dpd.is_ctrl d then (`Arrowhead `Odot)::attrib else attrib
      in
      let attrib =
        if Dpd.is_addr d then (`Style `Dotted)::attrib else attrib
      in attrib

    let get_subgraph v =
      let mk_subgraph name attrib =
        let attrib = (`Style `Filled) :: attrib in
        Some { Graph.Graphviz.DotAttributes.sg_name= name;
               Graph.Graphviz.DotAttributes.sg_attributes = attrib }
      in
      match Node.elem_key v with
      | PdgIndex.Key.CallStmt call | PdgIndex.Key.SigCallKey (call, _) ->
        let call_stmt = PdgIndex.Key.call_from_id call in
        let name = "Call"^(string_of_int call_stmt.sid) in
        let call_txt =
          Pretty_utils.sfprintf "%a"
            (fun fmt ->
              Cil.defaultCilPrinter#pStmtKind call_stmt fmt
            )
            call_stmt.skind  in
        let call_txt = String.escaped call_txt in
        let attrib = [(`Label (name^" : "^call_txt))] in
        let attrib = (`Fillcolor 0xB38B4D) :: attrib in
        mk_subgraph name attrib
      | PdgIndex.Key.SigKey k ->
        let pack_inputs_outputs = false in
        if pack_inputs_outputs then
          begin
            let is_in =  match k with PdgIndex.Signature.In _ -> true | _ -> false in
            let name = if is_in then "Inputs" else "Outputs" in
            let color = if is_in then 0x90EE90 else 0x6495ED in
            let attrib = [] in
            let attrib = (`Fillcolor color) :: attrib in
            mk_subgraph name attrib
          end
        else
          None
      | _ -> None
  end

  (** @see <http://www.lri.fr/~filliatr/ocamlgraph/doc/Graphviz.html>
    *        Graph.Graphviz *)
  module PrintG = Graph.Graphviz.Dot(Printer)

  (*-----------------------------------------------------------------------*)
  (** build the PDG .dot file and put it in [filename].  *)
  let build_dot filename pdg =
    let file = open_out filename in
    PrintG.output_graph file pdg;
    close_out file

  (** build the .dot file and put it in [pdg function name.dot]  *)
  let build_dot_file pdg =
    let kf = get_kf pdg in
    let fct_name = Kernel_function.get_name kf in
    let filename = (fct_name ^ ".dot") in
    build_dot filename pdg;
    filename

end

(*
Local Variables:
compile-command: "make -C ../.."
End:
*)
