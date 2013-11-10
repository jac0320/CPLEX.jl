export CplexSolver

type CplexMathProgModel <: AbstractMathProgModel
  inner::CPXproblem
end

immutable CplexSolver <: AbstractMathProgSolver
  options
end

CplexSolver(;kwargs...) = CplexSolver(kwargs)

function CplexMathProgModel(options)
  env = make_env()
  for (name,value) in options
    setparam!(env, string(name), value)
  end
  m = CplexMathProgModel(make_problem(env))
  return m
end

model(s::CplexSolver) = CplexMathProgModel(s.options)

loadproblem!(m::CplexMathProgModel, filename::String) = read_file!(m.inner, filename)

function loadproblem!(m::CplexMathProgModel, A, collb, colub, obj, rowlb, rowub, sense)
  add_vars!(m.inner, float(obj), float(collb), float(colub))

  neginf = typemin(eltype(rowlb))
  posinf = typemax(eltype(rowub))

  rangeconstrs = any((rowlb .!= rowub) & (rowlb .> neginf) & (rowub .< posinf))
  if rangeconstrs
    warn("Julia Cplex interface doesn't properly support range (two-sided) constraints.")
    add_rangeconstrs!(m.inner, float(A), float(rowlb), float(rowub))
  else
    b = Array(Float64,length(rowlb))
    senses = Array(Cchar,length(rowlb))
    for i in 1:length(rowlb)
      if rowlb[i] == rowub[i]
        senses[i] = 'E'
        b[i] = rowlb[i]
      elseif rowlb[i] > neginf
        senses[i] = 'G'
        b[i] = rowlb[i]
      else
        @assert rowub[i] < posinf
        senses[i] = 'L'
        b[i] = rowub[i]
      end
    end
    add_constrs!(m.inner, float(A), senses, b)
  end

  set_sense!(m.inner, sense)
end

writeproblem(m::CplexMathProgModel, filename::String) = write_model(m.inner, filename)

getVarLB(m::CplexMathProgModel) = get_varLB(m.inner)
setVarLB!(m::CplexMathProgModel, l) = set_varLB!(m.inner, l)
getVarUB(m::CplexMathProgModel) = get_varUB(m.inner)
setVarUB!(m::CplexMathProgModel, u) = set_varUB!(m.inner, u)

# CPXchgcoef
getConstrLB(m::CplexMathProgModel) = get_constrLB(m.inner)
setConstrLB!(m::CplexMathProgModel, lb) = set_constrLB(m.inner, lb)
getConstrUB(m::CplexMathProgModel) = get_constrUB(m.inner)
setConstrUB!(m::CplexMathProgModel, ub) = set_constrUB(m.inner, ub)

getobj(m::CplexMathProgModel) = get_obj(m.inner)
setobj!(m::CplexMathProgModel, c) = set_obj!(m.inner, c)

addvar!(m::CplexMathProgModel, constridx, constrcoef, l, u, coeff) = add_var!(m.inner, constridx, constrcoef, l, u, coeff)

function addconstr!(m::CplexMathProgModel, varidx, coef, lb, ub) 
  neginf = typemin(eltype(lb))
  posinf = typemax(eltype(ub))

  rangeconstrs = any((lb .!= rowub) & (lb .> neginf) & (ub .< posinf))
  if rangeconstrs
    warn("Julia Cplex interface doesn't properly support range (two-sided) constraints.")
    add_rangeconstrs!(m.inner, [0], varidx, float(coef), float(lb), float(ub))
  else
    if lb == ub
      rel = 'E'
      rhs = lb
    elseif lb > neginf
      rel = 'G'
      rhs = lb
    else
      @assert ub < posinf
      rel = 'L'
      rhs = ub
    end
    add_constrs!(m.inner, [0], varidx, float(coef), rel, float(rhs))
  end
end

updatemodel!(m::CplexMathProgModel) = warn("Model update not necessary for Cplex.")

setsense!(m::CplexMathProgModel, sense) = set_sense!(m.inner, sense)

getsense(m::CplexMathProgModel) = get_sense(m.inner)

numvar(m::CplexMathProgModel) = num_var(m.inner)
numconstr(m::CplexMathProgModel) = num_constr(m.inner)

optimize!(m::CplexMathProgModel) = optimize!(m.inner)

function status(m::CplexMathProgModel)
  ret = get_status(m.inner)
  if ret in [:CPX_STAT_OPTIMAL, :CPXMIP_OPTIMAL]
    stat = :Optimal
  elseif ret in [:CPX_STAT_UNBOUNDED, :CPXMIP_UNBOUNDED]
    stat = :Unbounded
  elseif ret in [:CPX_STAT_INFEASIBLE, :CPXMIP_INFEASIBLE]
    stat = :Infeasible
  elseif ret in [:CPX_STAT_INForUNBD, :CPXMIP_INForUNBD]
    # this is an ugly hack that should be fixed at some point
    stat = :Unbounded
  else
    stat = ret
  end
  return stat
end

getobjval(m::CplexMathProgModel)   = get_solution(m.inner)[1]
getobjbound(m::CplexMathProgModel) = get_solution(m.inner)[1]
getsolution(m::CplexMathProgModel) = get_solution(m.inner)[2]
getconstrsolution(m::CplexMathProgModel) = get_constr_solution(m.inner)
getreducedcosts(m::CplexMathProgModel) = get_reduced_costs(m.inner)
getconstrduals(m::CplexMathProgModel) = get_constr_duals(m.inner)
getrawsolver(m::CplexMathProgModel) = m.inner

setvartype!(m::CplexMathProgModel, v::Vector{Char}) = set_vartype!(m.inner, v)
getvartype(m::CplexMathProgModel) = get_vartype(m.inner)