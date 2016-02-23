#  Copyright 2015, Vincent Leclere, Francois Pacaud and Henri Gerard
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.
#############################################################################
#  Define the extensive formulation to check the results of small problems
#############################################################################


function extensive_formulation(model, 
                               param)


    N_SCENARS = 10

    # Constants:
    V_MAX = 100
    V_MIN = 0

    C_MAX = round(Int, .4/7. * VOLUME_MAX) + 1
    C_MIN = 0
    
    DIM_STATE = model.dimStates
    DIM_CONTROL = model.dimControls
    
    X_init = [50, 50]
    
    laws = model.noises
    T = model.stageNumber-1
    
    mod = Model(solver=param.solver)
    
    
    #Calculate the number of nodes n at each step on the scenario tree
    N = Array{Int64,2}(zeros(T+1,1))
    N[1] = 1
    for t = 1 : (T)
        N[t+1] = N[t]*laws[t].supportSize
    end
    
    
    
    #Define the variables for the extensive formulation
    #At each node, we have as many variables as nodes
    @defVar(mod,  V_MIN <= x[t=1:T+1,n=1:DIM_STATE*N[t]] <= V_MAX)
    @defVar(mod,  C_MIN <= u[t=1:T,n=1:DIM_CONTROL*N[t+1]] <= C_MAX)
    @defVar(mod,  c[t=1:T,n=1:N_SCENARS*N[t]])
    
    
    #Define the conditional probabilities on each arc of the scenario tree
    #proba = Any[]
    proba = []
    push!(proba, laws[1].proba)
    for t = 2 : T
        println("t_proba",t)
        push!(proba, zeros(N[t+1]))
        for j = 1 : N[t]
            for k = 1 : N_SCENARS
                proba[t][N_SCENARS*(j-1)+k] = laws[t].proba[k]*proba[t-1][j]
            end
        end
    end
    
    
    #Instantiate the problem creating dynamic constraint at each node
    for t = 1 : (T)
        println("\n\nt=",t)
        for n = 1 : N[t]
            for xi = 1 : laws[t].supportSize
                m = (n-1)*laws[t].supportSize+xi
                @addConstraint(mod, 
                [x[t+1,DIM_STATE*(m-1)+k] for k = 1:DIM_STATE] .== model.dynamics(t,
                                                                                    [x[t,DIM_STATE*(n-1)+k] for k = 1:DIM_STATE],
                                                                                    [u[t,DIM_CONTROL*(m-1)+k] for k = 1:DIM_CONTROL],
                                                                                    laws[t].support[xi]))
                @addConstraint(mod, 
                c[t,m] == model.costFunctions(t, 
                                                [x[t,DIM_STATE*(n-1)+k] for k = 1:DIM_STATE],
                                                [u[t,DIM_CONTROL*(m-1)+k] for k = 1:DIM_CONTROL], 
                                                laws[t].support[xi]))
            end
        end
    end
    
    #Initial state
    @addConstraint(mod, [x[1,k] for k = 1:DIM_STATE] .== X_init)
    
    
    #Define the objective of the function
    @setObjective(mod, Min, sum{ sum{proba[t][N_SCENARS*(n-1)+k]*c[t,N_SCENARS*(n-1)+k],k = 1:N_SCENARS} , t = 1:T, n=1:div(N[t+1],N_SCENARS)})
    
    
    
    status = solve(mod)
    
    solved = (status == :Optimal)
    
    if solved
        println("resultat = ",getObjectiveValue(mod))
    end 
    
end
