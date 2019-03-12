# This file contains implementations of functions that are shared by mi formulation

AllAbstractMIForms = Union{AbstractMISOCPForm, AbstractMINLPForm, AbstractMISOCPDirectedForm, AbstractMINLPDirectedForm} # TODO rename to AbstractMIForms


#######################################################################################################################
# Common MI Variables
#######################################################################################################################

"Variables needed for modeling flow in MI models"
function variable_flow(gm::GenericGasModel, n::Int=gm.cnw; bounded::Bool = true) where T <: AllAbstractMIForms
    variable_mass_flow(gm,n; bounded=bounded)
    variable_connection_direction(gm,n)
end

"Variables needed for modeling flow in MI models when some edges are directed"
function variable_flow_directed(gm::GenericGasModel{T}, n::Int=gm.cnw; bounded::Bool = true) where T <: AllAbstractMIForms
    variable_mass_flow(gm,n; bounded=bounded)
    variable_connection_direction(gm,n;connection=gm.ref[:nw][n][:undirected_connection])
end

"Variables needed for modeling flow in MI models"
function variable_flow_ne(gm::GenericGasModel{T}, n::Int=gm.cnw; bounded::Bool = true) where T <: AllAbstractMIForms
    variable_mass_flow_ne(gm,n; bounded=bounded)
    variable_connection_direction_ne(gm,n)
end

"Variables needed for modeling flow in MI models when some edges are directed"
function variable_flow_ne_directed(gm::GenericGasModel{T}, n::Int=gm.cnw; bounded::Bool = true) where T <: AllAbstractMIForms
    variable_mass_flow_ne(gm,n; bounded=bounded)
    variable_connection_direction_ne(gm,n;ne_connection=gm.ref[:nw][n][:undirected_ne_connection])
end

########################################################################################################
## Versions of constraints used to compute flow balance
########################################################################################################

"Constraint for computing mass flow balance at node"
function constraint_junction_mass_flow(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    junction = ref(gm,n,:junction,i)
    constraint_junction_mass_flow_balance(gm, n, i)

    consumers = Dict(x for x in gm.ref[:nw][n][:consumer] if x.second["ql_junc"] == i)
    producers = Dict(x for x in gm.ref[:nw][n][:producer] if x.second["qg_junc"] == i)
    fgfirm     = length(producers) > 0 ? sum(calc_fgfirm(gm.data, producer) for (j, producer) in producers) : 0
    flfirm     = length(consumers) > 0 ? sum(calc_flfirm(gm.data, consumer) for (j, consumer) in consumers) : 0

    if fgfirm > 0.0 && flfirm == 0.0
        constraint_source_flow(gm, n, i)
    end

    if fgfirm == 0.0 && flfirm > 0.0
        constraint_sink_flow(gm, n, i)
    end

    if fgfirm == 0.0 && flfirm == 0.0 && junction["degree"] == 2
        constraint_conserve_flow(gm, n, i)
    end
end

"Constraint for computing mass flow balance at a node when some edges are directed"
function constraint_junction_mass_flow_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_junction_mass_flow_balance(gm, n, i)

    # TODO there is an analogue of constraint_source_flow, constraint_sink_flow, and constraint_conserve_flow
end

"Constraint for computing mass flow balance at node when injections are variables"
function constraint_junction_mass_flow_ls(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    junction = ref(gm,n,:junction,i)
    constraint_junction_mass_flow_balance_ls(gm, n, i)

    consumers = Dict(x for x in gm.ref[:nw][n][:consumer] if x.second["ql_junc"] == i)
    producers = Dict(x for x in gm.ref[:nw][n][:producer] if x.second["qg_junc"] == i)

    fgfirm    = length(producers) > 0 ? sum(calc_fgfirm(gm.data, producer) for (j, producer) in producers) : 0
    flfirm    = length(consumers) > 0 ? sum(calc_flfirm(gm.data, consumer) for (j, consumer) in consumers) : 0
    fgmax     = length(producers) > 0 ? sum(calc_fgmax(gm.data, producer) for (j, producer) in producers) : 0
    flmax     = length(consumers) > 0 ? sum(calc_flmax(gm.data, consumer) for (j, consumer) in consumers) : 0
    fgmin     = length(producers) > 0 ? sum(calc_fgmin(gm.data, producer) for (j, producer) in producers) : 0
    flmin     = length(consumers) > 0 ? sum(calc_flmin(gm.data, consumer) for (j, consumer) in consumers) : 0

    if max(fgmin,fgfirm) > 0.0  && flmin == 0.0 && flmax == 0.0 && flfirm == 0.0 && fgmin >= 0.0
        constraint_source_flow(gm, n, i)
    end

    if fgmax == 0.0 && fgmin == 0.0 && fgfirm == 0.0 && max(flmin,flfirm) > 0.0 && flmin >= 0.0
        constraint_sink_flow(gm, n, i)
    end

    if fgmax == 0 && fgmin == 0 && fgfirm == 0 && flmax == 0 && flmin == 0 && flfirm == 0 && junction["degree"] == 2
        constraint_conserve_flow(gm, n, i)
    end
end

"Constraint for computing mass flow balance at node when injections are variables and some edges are directed"
function constraint_junction_mass_flow_ls_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_junction_mass_flow_balance_ls(gm, n, i)

    # TODO there is an analogue of constraint_source_flow, constraint_sink_flow, and constraint_conserve_flow
end

"Constraint for computing mass flow balance at node when there are expansion edges"
function constraint_junction_mass_flow_ne(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    junction = ref(gm,n,:junction,i)
    constraint_junction_mass_flow_balance_ne(gm, n, i)

    consumers = Dict(x for x in gm.ref[:nw][n][:consumer] if x.second["ql_junc"] == i)
    producers = Dict(x for x in gm.ref[:nw][n][:producer] if x.second["qg_junc"] == i)
    fgfirm     = length(producers) > 0 ? sum(calc_fgfirm(gm.data, producer) for (j, producer) in producers) : 0
    flfirm     = length(consumers) > 0 ? sum(calc_flfirm(gm.data, consumer) for (j, consumer) in consumers) : 0

    if fgfirm > 0.0 && flfirm == 0.0
        constraint_source_flow_ne(gm, n, i)
    end
    if fgfirm == 0.0 && flfirm > 0.0
        constraint_sink_flow_ne(gm, n, i)
    end
    if fgfirm == 0.0 && flfirm == 0.0 && junction["degree_all"] == 2
        constraint_conserve_flow_ne(gm, n, i)
    end
end

"Constraint for computing mass flow balance at node when there are expansion edges and some edges are directed"
function constraint_junction_mass_flow_ne_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_junction_mass_flow_balance_ne(gm, n, i)

    # TODO there is an analogue of constraint_source_flow, constraint_sink_flow, and constraint_conserve_flow
end

"Constraint for computing mass flow balance at node when there are expansion edges and variable injections"
function constraint_junction_mass_flow_ne_ls(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    junction = ref(gm,n,:junction,i)
    constraint_junction_mass_flow_balance_ne_ls(gm, n, i)

    consumers = Dict(x for x in gm.ref[:nw][n][:consumer] if x.second["ql_junc"] == i)
    producers = Dict(x for x in gm.ref[:nw][n][:producer] if x.second["qg_junc"] == i)
    fgfirm    = length(producers) > 0 ? sum(calc_fgfirm(gm.data, producer) for (j, producer) in producers) : 0
    flfirm    = length(consumers) > 0 ? sum(calc_flfirm(gm.data, consumer) for (j, consumer) in consumers) : 0
    fgmax     = length(producers) > 0 ? sum(calc_fgmax(gm.data, producer) for (j, producer) in producers) : 0
    flmax     = length(consumers) > 0 ? sum(calc_flmax(gm.data, consumer) for (j, consumer) in consumers) : 0
    fgmin     = length(producers) > 0 ? sum(calc_fgmin(gm.data, producer) for (j, producer) in producers) : 0
    flmin     = length(consumers) > 0 ? sum(calc_flmin(gm.data, consumer) for (j, consumer) in consumers) : 0

    if max(fgmin,fgfirm) > 0.0  && flmin == 0.0 && flmax == 0.0 && flfirm == 0.0 && fgmin >= 0.0
        constraint_source_flow_ne(gm, i)
    end
    if fgmax == 0.0 && fgmin == 0.0 && fgfirm == 0.0 && max(flmin,flfirm) > 0.0 && flmin >= 0.0
        constraint_sink_flow_ne(gm, i)
    end
    if fgmax == 0 && fgmin == 0 && fgfirm == 0 && flmax == 0 && flmin == 0 && flfirm == 0 && junction["degree_all"] == 2
        constraint_conserve_flow_ne(gm, i)
    end
end

"Constraint for computing mass flow balance at node when there are expansion edges, variable injections, and some edges are directed"
function constraint_junction_mass_flow_ne_ls_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_junction_mass_flow_balance_ne_ls(gm, n, i)

    # TODO there is an analogue of constraint_source_flow, constraint_sink_flow, and constraint_conserve_flow
end


#############################################################################################################
## Constraints for modeling flow across a pipe
############################################################################################################

"Constraints the define the pressure drop across a pipe"
function constraint_pipe_flow(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_pressure_drop(gm, i)
    constraint_on_off_pipe_flow(gm, i)
    constraint_weymouth(gm, i)

    constraint_flow_direction_choice(gm, i)
    constraint_parallel_flow(gm, i)
end

"Constraints the define the pressure drop across a pipe when some pipe directions are known"
function constraint_pipe_flow_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_pressure_drop_directed(gm, i)
    constraint_on_off_pipe_flow_directed(gm, i)
    constraint_weymouth_directed(gm, i)
end

" constraints for modeling flow across an undirected pipe when there are new edges "
function constraint_pipe_flow_ne(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_pressure_drop(gm, i)
    constraint_on_off_pipe_flow(gm, i)
    constraint_weymouth(gm, i)

    constraint_flow_direction_choice(gm, i)
    constraint_parallel_flow_ne(gm, i)
end

" constraints on pressure drop across an undirected pipe"
function constraint_on_off_pressure_drop(gm::GenericGasModel{T}, n::Int, k, i, j, pd_min, pd_max) where T <: AllAbstractMIForms
    yp = gm.var[:nw][n][:yp][k]
    yn = gm.var[:nw][n][:yn][k]
    constraint_on_off_pressure_drop(gm, n, k, i, j, pd_min, pd_max, yp, yn)
end

" constraints on pressure drop across an undirected pipe"
function constraint_on_off_pressure_drop(gm::GenericGasModel{T}, n::Int, k, i, j, pd_min, pd_max, yp, yn) where T <: AllAbstractMIForms
    pi = gm.var[:nw][n][:p][i]
    pj = gm.var[:nw][n][:p][j]

    if !haskey(gm.con[:nw][n], :on_off_pressure_drop1)
        gm.con[:nw][n][:on_off_pressure_drop1] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_pressure_drop2] = Dict{Int,ConstraintRef}()
    end
    gm.con[:nw][n][:on_off_pressure_drop1][k] = @constraint(gm.model, (1-yp) * pd_min <= pi - pj)
    gm.con[:nw][n][:on_off_pressure_drop2][k] = @constraint(gm.model, pi - pj <= (1-yn)* pd_max)
end

" constraints on pressure drop across a directed pipe"
function constraint_on_off_pressure_drop_directed(gm::GenericGasModel{T}, n::Int, k, i, j, pd_min, pd_max, yp, yn) where T <: AllAbstractMIForms
    constraint_on_off_pressure_drop(gm, n, k, i, j, pd_min, pd_max, yp, yn)
end

" constraint on flow across an undirected pipe "
function constraint_on_off_pipe_flow(gm::GenericGasModel{T}, n::Int, k; pipe_resistance=calc_pipe_resistance_thorley, resistor_resistance=calc_resistor_resistance_simple) where T <: AllAbstractMIForms
    pipe = ref(gm,n,:connection,k)

    i              = pipe["f_junction"]
    j              = pipe["t_junction"]
    mf             = gm.ref[:nw][n][:max_mass_flow]
    pd_max         = pipe["pd_max"]
    pd_min         = pipe["pd_min"]
    w              = haskey(gm.ref[:nw][n][:pipe],k) ? pipe_resistance(gm.data, pipe) : resistor_resistance(gm.data, pipe)
    constraint_on_off_pipe_flow(gm, n, k, i, j, mf, pd_min, pd_max, w)
end
constraint_on_off_pipe_flow(gm::GenericGasModel, k::Int) = constraint_on_off_pipe_flow(gm, gm.cnw, k)

" constraint on flow across a directed pipe "
function constraint_on_off_pipe_flow_directed(gm::GenericGasModel{T}, n::Int, k; pipe_resistance=calc_pipe_resistance_thorley, resistor_resistance=calc_resistor_resistance_simple) where T <: AllAbstractMIForms
    pipe = ref(gm,n,:connection,k)

    i              = pipe["f_junction"]
    j              = pipe["t_junction"]
    mf             = gm.ref[:nw][n][:max_mass_flow]
    pd_max         = pipe["pd_max"]
    pd_min         = pipe["pd_min"]
    w              = haskey(gm.ref[:nw][n][:pipe],k) ? pipe_resistance(gm.data, pipe) : resistor_resistance(gm.data, pipe)
    yp             = pipe["yp"]
    yn             = pipe["yn"]

    constraint_on_off_pipe_flow_directed(gm, n, k, i, j, mf, pd_min, pd_max, w, yp, yn)
end
constraint_on_off_pipe_flow_directed(gm::GenericGasModel, k::Int) = constraint_on_off_pipe_flow_directed(gm, gm.cnw, k)

" constraint on flow across an undirected pipe "
function constraint_on_off_pipe_flow(gm::GenericGasModel{T}, n::Int, k, i, j, mf, pd_min, pd_max, w) where T <: AllAbstractMIForms
    yp = gm.var[:nw][n][:yp][k]
    yn = gm.var[:nw][n][:yn][k]
   constraint_on_off_pipe_flow(gm, n, k, i, j, mf, pd_min, pd_max, w, yp, yn)
end

" generic constraint on flow across the pipe where direction is passed in as a variable or constant"
function constraint_on_off_pipe_flow(gm::GenericGasModel{T}, n::Int, k, i, j, mf, pd_min, pd_max, w, yp, yn) where T <: AllAbstractMIForms
    f  = gm.var[:nw][n][:f][k]

    if !haskey(gm.con[:nw][n], :on_off_pipe_flow1)
        gm.con[:nw][n][:on_off_pipe_flow1] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_pipe_flow2] = Dict{Int,ConstraintRef}()
    end
    gm.con[:nw][n][:on_off_pipe_flow1][k] = @constraint(gm.model, -(1-yp)*min(mf, sqrt(w*max(pd_max, abs(pd_min)))) <= f)
    gm.con[:nw][n][:on_off_pipe_flow2][k] = @constraint(gm.model, f <= (1-yn)*min(mf, sqrt(w*max(pd_max, abs(pd_min)))))
end

" constraints on flow across a directed pipe "
function constraint_on_off_pipe_flow_directed(gm::GenericGasModel{T}, n::Int, k, i, j, mf, pd_min, pd_max, w, yp, yn) where T <: AllAbstractMIForms
    constraint_on_off_pipe_flow(gm, n, k, i, j, mf, pd_min, pd_max, w, yp, yn)
end

#############################################################################################################
## Constraints for modeling flow across a new pipe
############################################################################################################

"Constraints for an expansion pipe with undirected flow"
function constraint_new_pipe_flow_ne(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_pressure_drop_ne(gm, i)
    constraint_on_off_pipe_flow_ne(gm, i)
    constraint_on_off_pipe_ne(gm, i)
    constraint_weymouth_ne(gm, i)

    constraint_flow_direction_choice_ne(gm, i)
    constraint_parallel_flow_ne(gm, i)
end

"Constraints for an expansion pipe with undirected flow"
function constraint_new_pipe_flow_ne_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_pressure_drop_ne_directed(gm, i)
    constraint_on_off_pipe_flow_ne_directed(gm, i)
    constraint_on_off_pipe_ne(gm, i)
    constraint_weymouth_ne_directed(gm, i)
end

" constraints on flow across an expansion pipe that is undirected "
function constraint_on_off_pipe_flow_ne(gm::GenericGasModel, n::Int, k; pipe_resistance=calc_pipe_resistance_thorley, resistor_resistance=calc_resistor_resistance_simple)
    pipe = ref(gm,n,:ne_connection, k)

    i              = pipe["f_junction"]
    j              = pipe["t_junction"]
    mf             = gm.ref[:nw][n][:max_mass_flow]
    pd_max         = pipe["pd_max"]
    pd_min         = pipe["pd_min"]
    w              = haskey(gm.ref[:nw][n][:ne_pipe],k) ? pipe_resistance(gm.data, pipe) : resistor_resistance(gm.data, pipe)

    constraint_on_off_pipe_flow_ne(gm, n, k, i, j, mf, pd_min, pd_max, w)
end
constraint_on_off_pipe_flow_ne(gm::GenericGasModel, k::Int) = constraint_on_off_pipe_flow_ne(gm, gm.cnw, k)

" constraints on flow across an expansion pipe that is directed "
function constraint_on_off_pipe_flow_ne_directed(gm::GenericGasModel, n::Int, k; pipe_resistance=calc_pipe_resistance_thorley, resistor_resistance=calc_resistor_resistance_simple)
    pipe = ref(gm,n,:ne_connection, k)

    i              = pipe["f_junction"]
    j              = pipe["t_junction"]
    mf             = gm.ref[:nw][n][:max_mass_flow]
    pd_max         = pipe["pd_max"]
    pd_min         = pipe["pd_min"]
    w              = haskey(gm.ref[:nw][n][:ne_pipe],k) ? pipe_resistance(gm.data, pipe) : resistor_resistance(gm.data, pipe)
    yp             = pipe["yp"]
    yn             = pipe["yn"]

    constraint_on_off_pipe_flow_ne_directed(gm, n, k, i, j, mf, pd_min, pd_max, w, yp, yn)
end
constraint_on_off_pipe_flow_ne_directed(gm::GenericGasModel, k::Int) = constraint_on_off_pipe_flow_ne_directed(gm, gm.cnw, k)

" constraints on pressure drop across an undirected expansion pipe "
function constraint_on_off_pressure_drop_ne(gm::GenericGasModel{T}, n::Int, k, i, j, pd_min, pd_max) where T <: AllAbstractMIForms
    yp = gm.var[:nw][n][:yp_ne][k]
    yn = gm.var[:nw][n][:yn_ne][k]
    constraint_on_off_pressure_drop_ne(gm, n, k, i, j, pd_min, pd_max, yp, yn)
end

" constraints on pressure drop across a pipe "
function constraint_on_off_pressure_drop_ne(gm::GenericGasModel{T}, n::Int, k, i, j, pd_min, pd_max, yp, yn) where T <: AllAbstractMIForms
    pi = gm.var[:nw][n][:p][i]
    pj = gm.var[:nw][n][:p][j]

    if !haskey(gm.con[:nw][n], :on_off_pressure_drop_ne1)
        gm.con[:nw][n][:on_off_pressure_drop_ne1] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_pressure_drop_ne2] = Dict{Int,ConstraintRef}()
    end
    gm.con[:nw][n][:on_off_pressure_drop_ne1][k] = @constraint(gm.model, (1-yp) * pd_min <= pi - pj)
    gm.con[:nw][n][:on_off_pressure_drop_ne2][k] = @constraint(gm.model, pi - pj <= (1-yn)* pd_max)
end

" constraints on pressure drop across pipes when the direction is fixed "
function constraint_on_off_pressure_drop_ne_directed(gm::GenericGasModel{T}, n::Int, k, i, j, pd_min, pd_max, yp, yn) where T <: AllAbstractMIForms
    constraint_on_off_pressure_drop_ne(gm, n, k, i, j, pd_min, pd_max, yp, yn)
end

" constraints on flow across an expansion undirected pipe "
function constraint_on_off_pipe_flow_ne(gm::GenericGasModel{T}, n::Int, k, i, j, mf, pd_min, pd_max, w) where T <: AllAbstractMIForms
    yp = gm.var[:nw][n][:yp_ne][k]
    yn = gm.var[:nw][n][:yn_ne][k]
    constraint_on_off_pipe_flow_ne(gm, n, k, i, j, mf, pd_min, pd_max, w, yp, yn)
end

" constraints on flow across an expansion pipe "
function constraint_on_off_pipe_flow_ne(gm::GenericGasModel{T}, n::Int, k, i, j, mf, pd_min, pd_max, w, yp, yn) where T <: AllAbstractMIForms
    f  = gm.var[:nw][n][:f_ne][k]

    if !haskey(gm.con[:nw][n], :on_off_pipe_flow_ne1)
        gm.con[:nw][n][:on_off_pipe_flow_ne1] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_pipe_flow_ne2] = Dict{Int,ConstraintRef}()
    end
    gm.con[:nw][n][:on_off_pipe_flow_ne1][k] = @constraint(gm.model, -(1-yp)*min(mf, sqrt(w*max(pd_max, abs(pd_min)))) <= f)
    gm.con[:nw][n][:on_off_pipe_flow_ne2][k] = @constraint(gm.model, f <= (1-yn)*min(mf, sqrt(w*max(pd_max, abs(pd_min)))))
end

" constraints on flow across an expansion pipe that is directed "
function constraint_on_off_pipe_flow_ne_directed(gm::GenericGasModel{T}, n::Int, k, i, j, mf, pd_min, pd_max, w, yp, yn) where T <: AllAbstractMIForms
    constraint_on_off_pipe_flow_ne(gm, n, k, i, j, mf, pd_min, pd_max, w, yp, yn)
end

###########################################################################################
### Short pipe constriants
###########################################################################################

" Constraints for modeling flow on an undirected short pipe"
function constraint_short_pipe_flow(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_short_pipe_pressure_drop(gm, i)
    constraint_on_off_short_pipe_flow(gm, i)

    constraint_flow_direction_choice(gm, i)
    constraint_parallel_flow(gm, i)
end

" Constraints for modeling flow on a directed short pipe"
function constraint_short_pipe_flow_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_short_pipe_pressure_drop(gm, i)
    constraint_on_off_short_pipe_flow_directed(gm, i)
end

" Constraints for modeling flow on an undirected short pipe for expansion planning models"
function constraint_short_pipe_flow_ne(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_short_pipe_pressure_drop(gm, i)
    constraint_on_off_short_pipe_flow(gm, i)

    constraint_flow_direction_choice(gm, i)
    constraint_parallel_flow_ne(gm, i)
end

" constraints on flow across a directed short pipe "
function constraint_on_off_short_pipe_flow_directed(gm::GenericGasModel{T}, n::Int, k, i, j, mf, yp, yn) where T <: AllAbstractMIForms
    constraint_on_off_short_pipe_flow(gm, n, k, i, j, mf, yp, yn)
end

" constraints on flow across a  short pipe "
function constraint_on_off_short_pipe_flow(gm::GenericGasModel{T}, n::Int, k, i, j, mf, yp, yn) where T <: AllAbstractMIForms
    f = gm.var[:nw][n][:f][k]

    if !haskey(gm.con[:nw][n], :on_off_short_pipe_flow1)
        gm.con[:nw][n][:on_off_short_pipe_flow1] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_short_pipe_flow2] = Dict{Int,ConstraintRef}()
    end
    gm.con[:nw][n][:on_off_short_pipe_flow1][k] = @constraint(gm.model, -mf*(1-yp) <= f)
    gm.con[:nw][n][:on_off_short_pipe_flow2][k] = @constraint(gm.model, f <= mf*(1-yn))
end

" constraints on flow across an undirected short pipe "
function constraint_on_off_short_pipe_flow(gm::GenericGasModel{T}, n::Int, k, i, j, mf) where T <: AllAbstractMIForms
    yp = gm.var[:nw][n][:yp][k]
    yn = gm.var[:nw][n][:yn][k]
    constraint_on_off_short_pipe_flow(gm, n, k, i, j, mf, yp, yn)
end

" constraints on flow across an undirected short pipe "
function constraint_on_off_short_pipe_flow(gm::GenericGasModel{T}, n::Int, k) where T <: AllAbstractMIForms
    pipe = ref(gm,n,:connection,k)

    i  = pipe["f_junction"]
    j  = pipe["t_junction"]
    mf = gm.ref[:nw][n][:max_mass_flow]

    constraint_on_off_short_pipe_flow(gm, n, k, i, j, mf)
end
constraint_on_off_short_pipe_flow(gm::GenericGasModel, k::Int) = constraint_on_off_short_pipe_flow(gm, gm.cnw, k)

" constraints on flow across a directed short pipe "
function constraint_on_off_short_pipe_flow_directed(gm::GenericGasModel{T}, n::Int, k) where T <: AllAbstractMIForms
    pipe = ref(gm,n,:connection,k)

    i  = pipe["f_junction"]
    j  = pipe["t_junction"]
    mf = gm.ref[:nw][n][:max_mass_flow]
    yp = pipe["yp"]
    yn = pipe["yn"]

    constraint_on_off_short_pipe_flow_directed(gm, n, k, i, j, mf, yp, yn)
end
constraint_on_off_short_pipe_flow_directed(gm::GenericGasModel, k::Int) = constraint_on_off_short_pipe_flow_directed(gm, gm.cnw, k)

######################################################################################
# Constraints associated with flow through a compressor
######################################################################################

"Constraints on flow through a compressor where the compressor is undirected"
function constraint_compressor_flow(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_compressor_flow(gm, i)
    constraint_on_off_compressor_ratios(gm, i)

    constraint_flow_direction_choice(gm, i)
    constraint_parallel_flow(gm, i)
end

"Constraints on flow through a compressor where the compressor is directed"
function constraint_compressor_flow_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_compressor_flow_directed(gm, i)
    constraint_on_off_compressor_ratios_directed(gm, i)
end

"Constraints through a new compressor that is undirected"
function constraint_new_compressor_flow_ne(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_compressor_flow_direction_ne(gm, i)
    constraint_on_off_compressor_ratios_ne(gm, i)
    constraint_on_off_compressor_ne(gm, i)

    constraint_flow_direction_choice_ne(gm, i)
    constraint_parallel_flow_ne(gm, i)
end

"Constraints through a new compressor that is directed"
function constraint_new_compressor_flow_ne_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_compressor_ne(gm, i)
    constraint_on_off_compressor_flow_direction_ne(gm, i)
    constraint_on_off_compressor_ratios_ne(gm, i)
end

"Constraints through a compressor that is undirected in an expansion model"
function constraint_compressor_flow_ne(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_compressor_flow(gm, i)
    constraint_on_off_compressor_ratios(gm, i)

    constraint_flow_direction_choice(gm, i)
    constraint_parallel_flow_ne(gm, i)
end

"Constraints through a compressor that is directed in an expansion model"
function constraint_compressor_flow_ne_directed(gm::GenericGasModel{T}, n::Int, i) where T <: AllAbstractMIForms
    constraint_on_off_compressor_flow_directed(gm, i)
    constraint_on_off_compressor_ratios_directed(gm, i)
end

" constraints on flow across an undirected compressor "
function constraint_on_off_compressor_flow(gm::GenericGasModel{T}, n::Int, k)  where T <: AllAbstractMIForms
    compressor = ref(gm, n, :connection, k)

    i        = compressor["f_junction"]
    j        = compressor["t_junction"]
    mf       = gm.ref[:nw][n][:max_mass_flow]

    constraint_on_off_compressor_flow(gm, n, k, i, j, mf)
end
constraint_on_off_compressor_flow(gm::GenericGasModel, k::Int) = constraint_on_off_compressor_flow(gm, gm.cnw, k)

" constraints on flow across a directed compressor "
function constraint_on_off_compressor_flow_directed(gm::GenericGasModel{T}, n::Int, k)  where T <: AllAbstractMIForms
    compressor = ref(gm, n, :connection, k)

    i        = compressor["f_junction"]
    j        = compressor["t_junction"]
    mf       = gm.ref[:nw][n][:max_mass_flow]
    yp       = compressor["yp"]
    yn       = compressor["yn"]

    constraint_on_off_compressor_flow_directed(gm, n, k, i, j, mf, yp, yn)
end
constraint_on_off_compressor_flow_directed(gm::GenericGasModel, k::Int) = constraint_on_off_compressor_flow_directed(gm, gm.cnw, k)

" constraints on flow across a directed compressor "
function constraint_on_off_compressor_flow_directed(gm::GenericGasModel{T}, n::Int, k, i, j, mf, yp, yn) where T <: AllAbstractMIForms
    constraint_on_off_compressor_flow(gm, n, k, i, j, mf, yp, yn)
end

" constraints on flow across an undirected compressor "
function constraint_on_off_compressor_flow(gm::GenericGasModel{T}, n::Int, k, i, j, mf) where T <: AllAbstractMIForms
    yp = gm.var[:nw][n][:yp][k]
    yn = gm.var[:nw][n][:yn][k]

    constraint_on_off_compressor_flow(gm, n, k, i, j, mf, yp, yn)
end

" constraints on flow across a compressor "
function constraint_on_off_compressor_flow(gm::GenericGasModel{T}, n::Int, k, i, j, mf, yp, yn) where T <: AllAbstractMIForms
    f  = gm.var[:nw][n][:f][k]

    if !haskey(gm.con[:nw][n], :on_off_compressor_flow_direction1)
        gm.con[:nw][n][:on_off_compressor_flow_direction1] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_compressor_flow_direction2] = Dict{Int,ConstraintRef}()
    end
    gm.con[:nw][n][:on_off_compressor_flow_direction1][k] = @constraint(gm.model, -(1-yp)*mf <= f)
    gm.con[:nw][n][:on_off_compressor_flow_direction2][k] = @constraint(gm.model, f <= (1-yn)*mf)
end

" enforces pressure changes bounds that obey compression ratios for an undirected compressor "
function constraint_on_off_compressor_ratios(gm::GenericGasModel{T}, n::Int, k) where T <: AllAbstractMIForms
    compressor     = ref(gm,n,:connection,k)
    i              = compressor["f_junction"]
    j              = compressor["t_junction"]
    max_ratio      = compressor["c_ratio_max"]
    min_ratio      = compressor["c_ratio_min"]
    j_pmax         = gm.ref[:nw][n][:junction][j]["pmax"]
    j_pmin         = gm.ref[:nw][n][:junction][j]["pmin"]
    i_pmax         = gm.ref[:nw][n][:junction][i]["pmax"]
    i_pmin         = gm.ref[:nw][n][:junction][i]["pmin"]

    constraint_on_off_compressor_ratios(gm, n, k, i, j, min_ratio, max_ratio, j_pmax, j_pmin, i_pmax, i_pmin)
end
constraint_on_off_compressor_ratios(gm::GenericGasModel, k::Int) = constraint_on_off_compressor_ratios(gm, gm.cnw, k)

" enforces pressure changes bounds that obey compression ratios for a directed compressor "
function constraint_on_off_compressor_ratios_directed(gm::GenericGasModel{T}, n::Int, k) where T <: AllAbstractMIForms
    compressor     = ref(gm,n,:connection,k)
    i              = compressor["f_junction"]
    j              = compressor["t_junction"]
    max_ratio      = compressor["c_ratio_max"]
    min_ratio      = compressor["c_ratio_min"]
    j_pmax         = gm.ref[:nw][n][:junction][j]["pmax"]
    j_pmin         = gm.ref[:nw][n][:junction][j]["pmin"]
    i_pmax         = gm.ref[:nw][n][:junction][i]["pmax"]
    i_pmin         = gm.ref[:nw][n][:junction][i]["pmin"]
    yp             = compressor["yp"]
    yn             = compressor["yn"]

    constraint_on_off_compressor_ratios_directed(gm, n, k, i, j, min_ratio, max_ratio, j_pmax, j_pmin, i_pmax, i_pmin, yp, yn)
end
constraint_on_off_compressor_ratios_directed(gm::GenericGasModel, k::Int) = constraint_on_off_compressor_ratios_directed(gm, gm.cnw, k)

" on/off constraint for compressors when the flow direction is constant "
function constraint_on_off_compressor_ratios_directed(gm::GenericGasModel{T}, n::Int, k, i, j, min_ratio, max_ratio, j_pmax, j_pmin, i_pmax, i_pmin, yp, yn) where T <: AllAbstractMIForms
    constraint_on_off_compressor_ratios(gm, n, k, i, j, min_ratio, max_ratio, j_pmax, j_pmin, i_pmax, i_pmin, yp, yn)
end

" enforces pressure changes bounds that obey compression ratios for an undirected compressor "
function constraint_on_off_compressor_ratios(gm::GenericGasModel{T}, n::Int, k, i, j, min_ratio, max_ratio, j_pmax, j_pmin, i_pmax, i_pmin) where T <: AllAbstractMIForms
    yp = gm.var[:nw][n][:yp][k]
    yn = gm.var[:nw][n][:yn][k]

    constraint_on_off_compressor_ratios(gm, n, k, i, j, min_ratio, max_ratio, j_pmax, j_pmin, i_pmax, i_pmin, yp, yn)
end

" enforces pressure changes bounds that obey compression ratios for a compressor "
function constraint_on_off_compressor_ratios(gm::GenericGasModel{T}, n::Int, k, i, j, min_ratio, max_ratio, j_pmax, j_pmin, i_pmax, i_pmin, yp, yn) where T <: AllAbstractMIForms
    pi = gm.var[:nw][n][:p][i]
    pj = gm.var[:nw][n][:p][j]

    if !haskey(gm.con[:nw][n], :on_off_compressor_ratios1)
        gm.con[:nw][n][:on_off_compressor_ratios1] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_compressor_ratios2] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_compressor_ratios3] = Dict{Int,ConstraintRef}()
        gm.con[:nw][n][:on_off_compressor_ratios4] = Dict{Int,ConstraintRef}()
    end

    gm.con[:nw][n][:on_off_compressor_ratios1][k] = @constraint(gm.model, pj - max_ratio^2*pi <= (1-yp)*(j_pmax^2))
    gm.con[:nw][n][:on_off_compressor_ratios2][k] = @constraint(gm.model, min_ratio^2*pi - pj <= (1-yp)*(i_pmax^2))
    gm.con[:nw][n][:on_off_compressor_ratios3][k] = @constraint(gm.model, pi - pj <= (1-yn)*(i_pmax^2))
    gm.con[:nw][n][:on_off_compressor_ratios4][k] = @constraint(gm.model, pj - pi <= (1-yn)*(j_pmax^2))
end