-- Implementation of Simplex: reduced, nested representation
--
-- Only works on regular arrays, i.e. all instances need to be same size
-- main As bs cs = list of optimal objective values
-- As are lists of the constraint coefficients (m rows, n columns)
-- bs are lists of the constraint values (m length)
-- cs are lists of the objective coefficients (n length)
--
-- ==
-- nobench input @tests/test_in.txt
-- output @tests/test_out.txt
--
-- compiled input @tests/gen_test_in.txt
-- output @tests/gen_test_out.txt

default(i32)
default(f32)

let pivot [n] [m] (A : [m][n]f32) (b : [m]f32) (c : [n]f32) (v:f32) (l:i32) (e:i32) =
  -- new constraint values
  let newb = b[l]/A[l,e]
  let bHat =
    map
      (\i -> unsafe if i == l then newb else b[i]-A[i,e]*newb)
      (iota m)

  -- new constraint coefficients
  let newArowc = 1f32/A[l,e]
  let newArow =
    map
      (\i -> unsafe if i == e then newArowc else A[l,i]/A[l,e])
      (iota n)
  let AHat =
    map
     (\i ->
        if i == l
        then newArow
        else map
          (\j ->
            unsafe
            if j == e
            then -A[i,e] * newArowc
            else A[i,j] - A[i,e] * newArow[j]
          )
          (iota n)
     )
     (iota m)

  -- new objective function
  let vHat = v + c[e] * newb -- line 14
  let cHat =
    map
      (\i -> unsafe if i == e then -c[e]*AHat[l,i] else c[i]-c[e]*AHat[l,i])
      (iota n)

  in (AHat, bHat, cHat, vHat)

let entering_variable [n] (c : [n]f32) : i32 =
  let (vals,_) =
    reduce
      (\(acc_index,acc_val) (index,vall) ->
        if acc_index < 0
        then
          if vall > 0f32
          then (index,vall)
          else (-1,0f32)
        else (acc_index,acc_val))
    (-1,0f32)
    (zip (iota n) c)
  in vals

let leaving_variable [n] [m] (A : [m][n]f32) (b : [m]f32) (e : i32) : i32 =
  let delta = map (\Arow bcon -> unsafe if Arow[e] > 0f32 then bcon/Arow[e] else f32.inf) A b
  let (vals,_) =
    reduce
      (\(acc_index,acc_val) (index,vall) ->
        if acc_val == f32.inf && vall == f32.inf then (-1,f32.inf)
        else if acc_val == f32.inf || vall < acc_val then (index,vall)
        else (acc_index, acc_val))
      (-1,f32.inf)
      (zip (iota m) delta)
  in vals

let simplex [n] [m] (A : [m][n]f32) (b : [m]f32) (c : [n]f32) (v : f32) =
  let e = entering_variable c
  let (_,_,_,v,_) = loop (A,b,c,v,e) while e != -1 do
    let l = leaving_variable A b e
    -- should have a check for if l == -1 here, but it will throw out of
    -- bounds error if not, so that'll do as our "Unbounded" result for now
    let (A,b,c,v) = unsafe pivot A b c v l e
    let e = entering_variable c
    in (A,b,c,v,e)
  in v

let main [h] [m] [n] (As:[h][m][n]f32) (bs:[h][m]f32) (cs:[h][n]f32) =
  map (\A b c -> simplex A b c 0f32) As bs cs
