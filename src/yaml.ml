type t =
  | Null
  | Bool of bool
  | Float of float
  | String of string
  | Seq of t list
  | Map of (string * t) list

let of_string : string -> (t , string) result = _

let to_string : t -> string = _
