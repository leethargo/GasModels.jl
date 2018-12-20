#Check the second order code model on load shedding
@testset "test misocp ls" begin
    @testset "gaslib 40 case" begin
        result = run_ls("../test/data/gaslib-40-ls.json", MISOCPGasModel, cvx_minlp_solver)
        @test result["status"] == :LocalOptimal || result["status"] == :Optimal
        @test isapprox(result["objective"]*result["solution"]["baseQ"], 516.053240741; atol = 1e-2)
     end      
end

#Check the second order code model on load shedding with priorities
@testset "test misocp ls priority" begin
    @testset "gaslib 40 case" begin
        result = run_ls("../test/data/gaslib-40-ls-priority.json", MISOCPGasModel, cvx_minlp_solver)
        @test result["status"] == :LocalOptimal || result["status"] == :Optimal || result["status"] == :Suboptimal
        @test isapprox(result["objective"]*result["solution"]["baseQ"], 464.44; atol = 1e-1) 
     end      
end
