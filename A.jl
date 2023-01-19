# 最大化利润

using JuMP
using HiGHS

#data
timber = ["MAT","KUT","KOT","MAK","KUK","KOK"]
productioncap1 = 200000 #MAS, KUS, KOS
productioncap2 = 90000  #KUV KOV
products1 = ["MAS","KUS","KOS","KUV","KOV"]
productioncap3 = 220000 #HSEL
productioncap4 = 180000 #LSEL
products2 = ["HSEL", "LSEL", "PAP"]
areas = ["EU","IE","PA","KI"]
sellingprice = zeros(8,4,2)
sellingprice[1,:,:] = [1600 4; 1300 7; 1400 12; 1500 15]
sellingprice[2,:,:] = [1400 3; 1200 10; 1300 12; 1400 15]
sellingprice[3,:,:] = [1300 14; 1400 20; 1500 23; 1600 25]
sellingprice[4,:,:] = [4400 4; 3800 10; 3600 12; 3500 17]
sellingprice[5,:,:] = [4300 4; 4100 8; 3900 12; 3800 15]
sellingprice[6,:,:] = [2300 3; 2500 4; 2300 5; 2600 6]
sellingprice[7,:,:] = [2500 3; 2800 2; 2300 7; 2500 7]
sellingprice[8,:,:] = [4500 5; 4700 10; 4300 12; 4800 15]

timber_assort = 
[
190 1;
150 0.5;
120 3;
180 0.2;
150 0.3;
150 0.2
]

woodproductmatrix = #cost,"MAT","KUT","KOT","MAK","KUK","KOK",FUEL
[
550 2 0 0 -0.8 0 0 -0.2;
500 0 2 0 0 -0.8 0 -0.2;
450 0 0 2 0 0 -0.8 -0.2;
2500 0 2.8 0 0 -1.6 0 -0.2;
2600 0 0 2.8 0 0 -1.6 -0.2
]

paperproductmatrix = 
[
820 4.8 0 0 0 0;
800 0 0 4.2 0 0;
1700 0 1 0 0.2 0.2
]



# Model
A = Model(HiGHS.Optimizer)

#variables
@variable(A,h[1:6]>=0)
@variable(A,woodproduct[1:5]>=0)
@variable(A,paperproduct[1:3]>=0)
#@variable(A,whethertosell[p=1:8,j=1:4],Bin)
@variable(A,q[p=1:8,j=1:4]>=0)
@variable(A,rawremain[1:6]>=0)
#@variable(A,whethertobuy[1:6],Bin)
#@variable(A,whetherpro1[1:3],Bin)
#@variable(A,noraw[i=1:6]>=0)
#@variable(A,nopro[p=1:8,a=1:4]>=0)


#objective
#总利润=收入-成本
#成本 = 采购成本 + 生产成本
#采购成本 = sum (alpha + beta * h) * h
#生产成本木头 = sum woodproduct[i]*c[i] for i=1:5
#生产成本纸浆 = sum paperproduct[i]*c[i] for i=1:3
#收入 = 销售收入 + 原料回收收入
#原料回收收入 = sum numberrawmaterialremain[i] * alpha[i] for i=1:6
#销售收入 = sum (r - epsilon * sellhowmuch)*sellhowmuch
@objective(A,Max,sum(rawremain[i]*timber_assort[i][1] for i=1:6) +  #剩余的原材料回收收入
sum((sellingprice[p,a,1] - sellingprice[p,a,2] * q[p,a]) * q[p,a] for p=1:8,a=1:4) - #出售产品收入
sum((timber_assort[i,1]+timber_assort[i,2]*h[i])*h[i] for i=1:6) -    #原材料采购成本
sum(woodproduct[p]*woodproductmatrix[p,1] for p=1:5) - #生产木头产品的成本
sum(paperproduct[p]*paperproductmatrix[p,1] for p=1:3) + #生产纸头产品的成本
sum(woodproduct[p]*0.2*40 for p=1:5 ) #燃料回收
)

#constraint
#@constraint(A,[i=1:6],noraw[i]*10 <= h[i])
#@constraint(A,[p=1:8,a=1:4],nopro[p,a]*10 <= q[p,a] )
#只有当bin=1时才能卖成品
#@constraint(A,[p=1:8,a=1:4],q[p,a] <= whethertosell[p,a]*99999999)

#如果卖了，大于10000
#@constraint(A,[p=1:8,a=1:4],q[p,a]>=10*whethertosell[p,a])

#只有当bin=1时才能买原材料
#@constraint(A,[i=1:6],h[i]<= whethertobuy[i]*9999999)

#如果买了，大于10000
#@constraint(A,[i=1:6],h[i]>=10*whethertobuy[i])

#容量要求
@constraint(A,sum(woodproduct[p] for p=1:3)<=200)
@constraint(A,sum(woodproduct[p] for p=4:5)<=90)
@constraint(A,paperproduct[1]+0.2*paperproduct[3]<=220)
@constraint(A,paperproduct[2]+0.2*paperproduct[3]<=180)
@constraint(A,paperproduct[3]<=80)


#生产方程式（木头）
@constraint(A,woodproduct[1]<=h[1]*0.5)
@constraint(A,woodproduct[2]<=h[2]*0.5)
@constraint(A,woodproduct[3]<=h[3]*0.5)
@constraint(A,woodproduct[4]<=h[2]/2.8)
@constraint(A,woodproduct[5]<=h[3]/2.8)

#生产方程式（纸和纸浆）
@constraint(A,paperproduct[1]<=(woodproduct[1]*0.8+h[4])/4.8)
@constraint(A,paperproduct[2]<= (woodproduct[3]*0.8+woodproduct[5]*1.6+h[6])/4.2            )
@constraint(A,paperproduct[3]<= (woodproduct[2]*0.8+woodproduct[4]*1.6+h[5])/1                               )
@constraint(A,paperproduct[3]<=    paperproduct[1]          /0.2   )
@constraint(A,paperproduct[3]<=   paperproduct[2]           /0.2   )



#剩下的原材料数量约束
@constraint(A,rawremain[1] <= h[1]-woodproduct[1]*2  )
@constraint(A,rawremain[2] <= h[2]-woodproduct[2]*2-woodproduct[4]*2.8)
@constraint(A,rawremain[3] <= h[3]-woodproduct[3]*2-woodproduct[5]*2.8)
@constraint(A,rawremain[4] <= h[4]+woodproduct[1]*0.8-paperproduct[1]*4.8)
@constraint(A,rawremain[5] <= h[5]+woodproduct[2]*0.8+woodproduct[4]*1.6-paperproduct[3]*1)
@constraint(A,rawremain[6] <= h[6]+woodproduct[3]*0.8+woodproduct[5]*1.6-paperproduct[2]*4.2)

#生产量 >= 销售量
@constraint(A,[p=1:5], woodproduct[p] >= sum(q[p,a] for a=1:4))
@constraint(A, paperproduct[1]-0.2*paperproduct[3] >= sum(q[6,a] for a=1:4))
@constraint(A, paperproduct[2]-0.2*paperproduct[3] >= sum(q[7,a] for a=1:4))
@constraint(A, paperproduct[3] >= sum(q[8,a] for a=1:4))


print(A)
optimize!(A)


println("Termination status: $(termination_status(A))")
if termination_status(A) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(A))")
    for p=1:5
        println("product[", p,"] : ",value(woodproduct[p]))
    end
    for p=1:3
        println("product[", p+5,"] : ",value(paperproduct[p]))
    end
    for t=1:6
        println("buy[",t,"] : ",value(h[t]))
    end
    for t=1:6
        println("rawremain[",t,"] : ",value(rawremain[t]))
    end
else
    println("No optimal solution available")
end

value(h[1])
value(h[2])
value(h[3])
value(h[4])
value(h[5])
value(h[6])

for p=1:8
    for a=1:4
        println(value(q[p,a]))
    end
end
