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
####################################################
############            求购买原材料的cost矩阵！！！！
cost = zeros(6,61)

for p=1:6
    for m=1:61
        cost[p,m] = (timber_assort[p,1] + timber_assort[p,2]*(m-1)*10)*(m-1)*10
    end
end
cost
sp =
[
1600 4;
1300 7;
1400 12; 
1500 15;
1400 3; 
1200 10;
1300 12; 
1400 15;
1300 14; 
1400 20; 
1500 23; 
1600 25;
4400 4; 
3800 10; 
3600 12; 
3500 17;
4300 4; 
4100 8; 
3900 12; 
3800 15;
2300 3; 
2500 4; 
2300 5; 
2600 6;
2500 3; 
2800 2; 
2300 7; 
2500 7;
4500 5; 
4700 10; 
4300 12; 
4800 15
]

sell = zeros(32,21)

for p=1:32
    for m=1:21
        sell[p,m] = (sp[p,1] - sp[p,2]*(m-1)*10)*(m-1)*10
    end
end




# Model
A = Model(HiGHS.Optimizer)

#variables
@variable(A,barge_buyBin[p=1:6,m=1:61],Bin)   #定义船只的数量，购买原材料的船只数量
@variable(A,barge_buy[p=1:6]>=0,Int)
#@variable(A,h[1:6]>=0)
@variable(A,woodproduct[1:5]>=0)
@variable(A,paperproduct[1:3]>=0)
#@variable(A,whethertosell[p=1:8,j=1:4],Bin)
#@variable(A,q[p=1:8,j=1:4]>=0)
@variable(A,barge_sellBin[p=1:32,m=1:21],Bin)
@variable(A,barge_sell[p=1:32]>=0,Int) #定义船只的数量，售卖产品到各地的船只数量
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
#每条船的购买成本：(alpha + 10beta)10 = 10alpha + 100beta 每条船的成本  
#总成本 = (10alpha + 100beta)*船只的数量
@objective(A,Max,sum(rawremain[i]*timber_assort[i][1] for i=1:6) + 
sum(sell[i,j]*barge_sellBin[i,j] for i=1:32,j=1:21) -   #销售收入
sum(cost[i,j]*barge_buyBin[i,j] for i=1:6,j=1:61) -    #原材料采购成本
sum(woodproduct[p]*woodproductmatrix[p,1] for p=1:5) - 
sum(paperproduct[p]*paperproductmatrix[p,1] for p=1:3) + 
sum(woodproduct[p]*0.2*40 for p=1:5 ) #燃料回收
)

#constraint
#@constraint(A,[i=1:6],noraw[i]*10 <= h[i])
#@constraint(A,[p=1:8,a=1:4],nopro[p,a]*10 <= q[p,a] )
@constraint(A,[p=1:32],sum(barge_sellBin[p,m] for m=1:21)==1)
@constraint(A,[p=1:6],sum(barge_buyBin[p,m] for m=1:61)==1)
@constraint(A,[p=1:6],barge_buy[p] == (sum(barge_buyBin[p,m]*m for m=1:61)-1))
@constraint(A,[p=1:32],barge_sell[p] == (sum(barge_sellBin[p,m]*m for m=1:21)-1))
#只有当bin=1时才能卖成品
#@constraint(A,[p=1:8,a=1:4],barge_sell[p,a] <= whethertosell[p,a]*99999999)

#如果卖了，大于10000
#@constraint(A,[p=1:8,a=1:4],barge_sell>=10*whethertosell[p,a])

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
@constraint(A,woodproduct[1]<=barge_buy[1]*10*0.5)
@constraint(A,woodproduct[2]<=barge_buy[2]*10*0.5)
@constraint(A,woodproduct[3]<=barge_buy[3]*10*0.5)
@constraint(A,woodproduct[4]<=barge_buy[2]*10/2.8)
@constraint(A,woodproduct[5]<=barge_buy[3]*10/2.8)

#生产方程式（纸和纸浆）
@constraint(A,paperproduct[1]<=(woodproduct[1]*0.8+barge_buy[4]*10)/4.8)
@constraint(A,paperproduct[2]<= (woodproduct[3]*0.8+woodproduct[5]*1.6+barge_buy[6]*10)/4.2            )
@constraint(A,paperproduct[3]<= (woodproduct[2]*0.8+woodproduct[4]*1.6+barge_buy[5]*10)/1                               )
@constraint(A,paperproduct[3]<=    paperproduct[1]          /0.2   )
@constraint(A,paperproduct[3]<=   paperproduct[2]           /0.2   )



#剩下的原材料数量约束
@constraint(A,rawremain[1] <= barge_buy[1]*10-woodproduct[1]*2  )
@constraint(A,rawremain[2] <= barge_buy[2]*10-woodproduct[2]*2-woodproduct[4]*2.8)
@constraint(A,rawremain[3] <= barge_buy[3]*10-woodproduct[3]*2-woodproduct[5]*2.8)
@constraint(A,rawremain[4] <= barge_buy[4]*10+woodproduct[1]*0.8-paperproduct[1]*4.8)
@constraint(A,rawremain[5] <= barge_buy[5]*10+woodproduct[2]*0.8+woodproduct[4]*1.6-paperproduct[3]*1)
@constraint(A,rawremain[6] <= barge_buy[6]*10+woodproduct[3]*0.8+woodproduct[5]*1.6-paperproduct[2]*4.2)

#生产量 >= 销售量

@constraint(A,woodproduct[1] >= barge_sell[1]*10 + barge_sell[2]*10 + barge_sell[3]*10 + barge_sell[4]*10)
@constraint(A,woodproduct[2] >= barge_sell[5]*10 + barge_sell[6]*10 + barge_sell[7]*10 + barge_sell[8]*10)
@constraint(A,woodproduct[3] >= barge_sell[9]*10 + barge_sell[10]*10 + barge_sell[11]*10 + barge_sell[12]*10)
@constraint(A,woodproduct[4] >= barge_sell[13]*10 + barge_sell[14]*10 + barge_sell[15]*10 + barge_sell[16]*10)
@constraint(A,woodproduct[5] >= barge_sell[17]*10 + barge_sell[18]*10 + barge_sell[19]*10 + barge_sell[20]*10)
@constraint(A, paperproduct[1]-0.2*paperproduct[3] >= barge_sell[21]*10 + barge_sell[22]*10 + barge_sell[23]*10 + barge_sell[24]*10)
@constraint(A, paperproduct[2]-0.2*paperproduct[3] >= barge_sell[25]*10 + barge_sell[26]*10 + barge_sell[27]*10 + barge_sell[28]*10)
@constraint(A, paperproduct[3] >= barge_sell[29]*10 + barge_sell[30]*10 + barge_sell[31]*10 + barge_sell[32]*10)


#@constraint(A,[p=1:5], woodproduct[p] >= sum(barge_sell[p,a]*10 for a=1:4))
#@constraint(A, paperproduct[1]-0.2*paperproduct[3] >= sum(barge_sell[6,a]*10 for a=1:4))
#@constraint(A, paperproduct[2]-0.2*paperproduct[3] >= sum(barge_sell[7,a]*10 for a=1:4))
#@constraint(A, paperproduct[3] >= sum(barge_sell[8,a]*10 for a=1:4))


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
        println("buy[",t,"] : ",value(barge_buy[t]))
    end
    for t=1:6
        println("rawremain[",t,"] : ",value(rawremain[t]))
    end
else
    println("No optimal solution available")
end

value(q[1,1])
value(q[1,2])
value(q[1,3])
value(q[1,4])
