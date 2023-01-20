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


#Exercise b
discountfac = 0.95
productioncap1 = 100 #MAS, KUS, KOS
productioncap2 = 90  #KUV KOV
productioncap3 = 100 #HSEL
productioncap4 = 150 #LSEL
productioncap5 = 80
intialcap = [100 90 100 150 80]
increcap = [1.5 1.5 2 2 2]
fixedcost =[100 300 300 500 700]
demandgrowth = [1.01 1.01 1.01 1.01 1.008 1.008 1.008 1.008 
1.015 1.015 1.015 1.015 1.015 1.015 1.015 1.015
1.02 1.02 1.02 1.02  1.025 1.025 1.025 1.025
1.03 1.03 1.03 1.03 1.035 1.035 1.035 1.035]
year = ["1","2","3"]
Y = length(year)
discount = [1, discountfac, discountfac*discountfac]

# Model
A = Model(HiGHS.Optimizer)

#variables
@variable(A,barge_buyBin[1:Y,p=1:6,m=1:61],Bin)   #定义船只的数量，购买原材料的船只数量
@variable(A,barge_buy[1:Y,p=1:6]>=0,Int)

@variable(A,woodproduct[1:Y,1:5]>=0)
@variable(A,paperproduct[1:Y,1:3]>=0)
@variable(A,barge_sellBin[1:Y,p=1:32,m=1:21],Bin)
@variable(A,barge_sell[1:Y,p=1:32]>=0,Int) #定义船只的数量，售卖产品到各地的船只数量
@variable(A,rawremain[1:Y,1:6]>=0)

@variable(A, r1[1:5]>=1)#
@variable(A, r2[1:5]>=1)
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
@objective(A,Max,sum(rawremain[y,i]*timber_assort[i,1]*discount[y] for y=1:Y,i=1:6) + 
sum(sell[i,j]*barge_sellBin[1,i,j] for i=1:32,j=1:21)+
sum(sell[i,j]*barge_sellBin[2,i,j]/demandgrowth[i] for i=1:32,j=1:21)*discountfac+
sum(sell[i,j]*barge_sellBin[3,i,j]/(demandgrowth[i]*demandgrowth[i]) for i=1:32,j=1:21)*discountfac*discountfac-   #销售收入
sum(cost[i,j]*barge_buyBin[y,i,j]*discount[y] for y=1:Y,i=1:6,j=1:61) -    #原材料采购成本
sum(woodproduct[y,p]*woodproductmatrix[p,1]*discount[y] for y=1:Y,p=1:5) - 
sum(paperproduct[y,p]*paperproductmatrix[p,1]*discount[y] for y=1:Y,p=1:3) + 
sum(woodproduct[y,p]*0.2*40*discount[y] for y=1:Y,p=1:5 ) #燃料回收
-sum(cap[p]*fixedcost[p]*r1[p] for p=1:5)
-sum(cap[p]*fixedcost[p]*r2[p] for p=1:5)*discountfac
-sum(cap[p]*fixedcost[p]*r2[p] for p=1:5)*discountfac*discountfac
)

#constraint
#@constraint(A,[i=1:6],noraw[i]*10 <= h[i])
#@constraint(A,[p=1:8,a=1:4],nopro[p,a]*10 <= q[p,a] )
@constraint(A,[y=1:Y,p=1:32],sum(barge_sellBin[y,p,m] for m=1:21)==1)
@constraint(A,[y=1:Y,p=1:6],sum(barge_buyBin[y,p,m] for m=1:61)==1)
@constraint(A,[y=1:Y,p=1:6],barge_buy[y,p] == (sum(barge_buyBin[y,p,m]*m for m=1:61)-1))
@constraint(A,[y=1:Y,p=1:32],barge_sell[y,p] == (sum(barge_sellBin[y,p,m]*m for m=1:21)-1))
#只有当bin=1时才能卖成品
#@constraint(A,[p=1:8,a=1:4],barge_sell[p,a] <= whethertosell[p,a]*99999999)

#如果卖了，大于10000
#@constraint(A,[p=1:8,a=1:4],barge_sell>=10*whethertosell[p,a])

#只有当bin=1时才能买原材料
#@constraint(A,[i=1:6],h[i]<= whethertobuy[i]*9999999)

#如果买了，大于10000
#@constraint(A,[i=1:6],h[i]>=10*whethertobuy[i])

#容量要求
#year1
@constraint(A,sum(woodproduct[1,p] for p=1:3)<=productioncap1)
@constraint(A,sum(woodproduct[1,p] for p=4:5)<=productioncap2)
@constraint(A,paperproduct[1,1]<=productioncap3)
@constraint(A,paperproduct[1,2]<=productioncap4)
@constraint(A,paperproduct[1,3]<=productioncap5)
#year2
@constraint(A,sum(woodproduct[2,p] for p=1:3)<=productioncap1*r1[1])
@constraint(A,sum(woodproduct[2,p] for p=4:5)<=productioncap2*r1[2])
@constraint(A,paperproduct[2,1]<=productioncap3*r1[3])
@constraint(A,paperproduct[2,2]<=productioncap4*r1[4])
@constraint(A,paperproduct[2,3]<=productioncap5*r1[5])
#year3
@constraint(A,sum(woodproduct[3,p] for p=1:3)<=productioncap1*r2[1])
@constraint(A,sum(woodproduct[3,p] for p=4:5)<=productioncap2*r2[2])
@constraint(A,paperproduct[3,1]<=productioncap3*r2[3])
@constraint(A,paperproduct[3,2]<=productioncap4*r2[4])
@constraint(A,paperproduct[3,3]<=productioncap5*r2[5])
#constraints of increase rates
@constraint(A,[p=1:5],r1[p] <= increcap[p])
@constraint(A,[p=1:5],r2[p] <= increcap[p])
@constraint(A,[p=1:5],r1[p] <= r2[p])

#生产方程式（木头）
@constraint(A,[y=1:Y],woodproduct[y,1]<=barge_buy[y,1]*10*0.5)
@constraint(A,[y=1:Y],woodproduct[y,2]<=barge_buy[y,2]*10*0.5)
@constraint(A,[y=1:Y],woodproduct[y,3]<=barge_buy[y,3]*10*0.5)
@constraint(A,[y=1:Y],woodproduct[y,4]<=barge_buy[y,2]*10/2.8)
@constraint(A,[y=1:Y],woodproduct[y,5]<=barge_buy[y,3]*10/2.8)

#生产方程式（纸和纸浆）
@constraint(A,[y=1:Y],paperproduct[y,1]<=(woodproduct[y,1]*0.8+barge_buy[y,4]*10)/4.8)
@constraint(A,[y=1:Y],paperproduct[y,2]<= (woodproduct[y,3]*0.8+woodproduct[y,5]*1.6+barge_buy[y,6]*10)/4.2)
@constraint(A,[y=1:Y],paperproduct[y,3]<= (woodproduct[y,2]*0.8+woodproduct[y,4]*1.6+barge_buy[y,5]*10)                             )
@constraint(A,[y=1:Y],paperproduct[y,3]<= paperproduct[y,1] /0.2)
@constraint(A,[y=1:Y],paperproduct[y,3]<= paperproduct[y,2] /0.2)



#剩下的原材料数量约束
@constraint(A,[y=1:Y],rawremain[y,1] <= barge_buy[y,1]*10-woodproduct[y,1]*2  )
@constraint(A,[y=1:Y],rawremain[y,2] <= barge_buy[y,2]*10-woodproduct[y,2]*2-woodproduct[y,4]*2.8)
@constraint(A,[y=1:Y],rawremain[y,3] <= barge_buy[y,3]*10-woodproduct[y,3]*2-woodproduct[y,5]*2.8)
@constraint(A,[y=1:Y],rawremain[y,4] <= barge_buy[y,4]*10+woodproduct[y,1]*0.8-paperproduct[y,1]*4.8)
@constraint(A,[y=1:Y],rawremain[y,5] <= barge_buy[y,5]*10+woodproduct[y,2]*0.8+woodproduct[y,4]*1.6-paperproduct[y,3]*1)
@constraint(A,[y=1:Y],rawremain[y,6] <= barge_buy[y,6]*10+woodproduct[y,3]*0.8+woodproduct[y,5]*1.6-paperproduct[y,2]*4.2)

#生产量 >= 销售量

@constraint(A,[y=1:Y],woodproduct[y,1] >= barge_sell[y,1]*10 + barge_sell[y,2]*10 + barge_sell[y,3]*10 + barge_sell[y,4]*10)
@constraint(A,[y=1:Y],woodproduct[y,2] >= barge_sell[y,5]*10 + barge_sell[y,6]*10 + barge_sell[y,7]*10 + barge_sell[y,8]*10)
@constraint(A,[y=1:Y],woodproduct[y,3] >= barge_sell[y,9]*10 + barge_sell[y,10]*10 + barge_sell[y,11]*10 + barge_sell[y,12]*10)
@constraint(A,[y=1:Y],woodproduct[y,4] >= barge_sell[y,13]*10 + barge_sell[y,14]*10 + barge_sell[y,15]*10 + barge_sell[y,16]*10)
@constraint(A,[y=1:Y],woodproduct[y,5] >= barge_sell[y,17]*10 + barge_sell[y,18]*10 + barge_sell[y,19]*10 + barge_sell[y,20]*10)
@constraint(A,[y=1:Y],paperproduct[y,1]-0.2*paperproduct[y,3] >= barge_sell[y,21]*10 + barge_sell[y,22]*10 + barge_sell[y,23]*10 + barge_sell[y,24]*10)
@constraint(A,[y=1:Y],paperproduct[y,2]-0.2*paperproduct[y,3] >= barge_sell[y,25]*10 + barge_sell[y,26]*10 + barge_sell[y,27]*10 + barge_sell[y,28]*10)
@constraint(A,[y=1:Y],paperproduct[y,3] >= barge_sell[y,29]*10 + barge_sell[y,30]*10 + barge_sell[y,31]*10 + barge_sell[y,32]*10)


#@constraint(A,[p=1:5], woodproduct[p] >= sum(barge_sell[p,a]*10 for a=1:4))
#@constraint(A, paperproduct[1]-0.2*paperproduct[3] >= sum(barge_sell[6,a]*10 for a=1:4))
#@constraint(A, paperproduct[2]-0.2*paperproduct[3] >= sum(barge_sell[7,a]*10 for a=1:4))
#@constraint(A, paperproduct[3] >= sum(barge_sell[8,a]*10 for a=1:4))


#print(A)
optimize!(A)

eu=[1,5,9,13,17,21,25,29]
ie=[2,6,10,14,18,22,26,30]
pa=[3,7,11,15,19,23,27,31]
ki=[4,8,12,16,20,24,28,32]
println("Termination status: $(termination_status(A))")
if termination_status(A) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(A))")
    println("The discounted profit for the first year:", 
    value(sum(rawremain[1,i]*timber_assort[i,1]*discount[1] for i=1:6) + 
    sum(sell[i,j]*barge_sellBin[1,i,j] for i=1:32,j=1:21)-
    sum(cost[i,j]*barge_buyBin[1,i,j]*discount[1] for i=1:6,j=1:61) -    #原材料采购成本
    sum(woodproduct[1,p]*woodproductmatrix[p,1]*discount[1] for p=1:5) - 
    sum(paperproduct[1,p]*paperproductmatrix[p,1]*discount[1] for p=1:3) + 
    sum(woodproduct[1,p]*0.2*40*discount[1] for p=1:5) #燃料回收
    -sum(cap[p]*fixedcost[p]*r1[p] for p=1:5)))

    println("The discounted profit for the second year:", 
    value(sum(rawremain[2,i]*timber_assort[i,1]*discount[2] for i=1:6) + 
    sum(sell[i,j]*barge_sellBin[2,i,j]/demandgrowth[i] for i=1:32,j=1:21)*discountfac-
    sum(cost[i,j]*barge_buyBin[2,i,j]*discount[2] for i=1:6,j=1:61) -    #原材料采购成本
    sum(woodproduct[2,p]*woodproductmatrix[p,1]*discount[2] for p=1:5) - 
    sum(paperproduct[2,p]*paperproductmatrix[p,1]*discount[2] for p=1:3) + 
    sum(woodproduct[2,p]*0.2*40*discount[2] for p=1:5) #燃料回收
    -sum(cap[p]*fixedcost[p]*r2[p] for p=1:5)*discountfac))

    println("The discounted profit for the third year:", 
    value(sum(rawremain[3,i]*timber_assort[i,1]*discount[3] for i=1:6) + 
    sum(sell[i,j]*barge_sellBin[3,i,j]/(demandgrowth[i]*demandgrowth[i]) for i=1:32,j=1:21)*discountfac*discountfac- 
    sum(cost[i,j]*barge_buyBin[3,i,j]*discount[3] for i=1:6,j=1:61) -    #原材料采购成本
    sum(woodproduct[3,p]*woodproductmatrix[p,1]*discount[3] for p=1:5) - 
    sum(paperproduct[3,p]*paperproductmatrix[p,1]*discount[3] for p=1:3) + 
    sum(woodproduct[3,p]*0.2*40*discount[3] for p=1:5) #燃料回收
    -sum(cap[p]*fixedcost[p]*r2[p] for p=1:5)*discountfac*discountfac))

    println("EU sale for the first tear:",
    value(sum(sell[i,j]*barge_sellBin[1,i,j] for i in eu, j=1:21) ))
    println("IE sale for the first tear:",
    value(sum(sell[i,j]*barge_sellBin[1,i,j] for i in ie, j=1:21) ))
    println("PA sale for the first tear:",
    value(sum(sell[i,j]*barge_sellBin[1,i,j] for i in pa, j=1:21) ))
    println("KI sale for the first tear:",
    value(sum(sell[i,j]*barge_sellBin[1,i,j] for i in ki, j=1:21) ))
    
    println("EU sale for the second tear:",
    value(sum(sell[i,j]*barge_sellBin[2,i,j] for i in eu, j=1:21) ))
    println("IE sale for the second tear:",
    value(sum(sell[i,j]*barge_sellBin[2,i,j] for i in ie, j=1:21) ))
    println("PA sale for the second tear:",
    value(sum(sell[i,j]*barge_sellBin[2,i,j] for i in pa, j=1:21) ))
    println("KI sale for the second tear:",
    value(sum(sell[i,j]*barge_sellBin[2,i,j] for i in ki, j=1:21) ))
    
    println("EU sale for the third tear:",
    value(sum(sell[i,j]*barge_sellBin[3,i,j] for i in eu, j=1:21) ))
    println("IE sale for the third tear:",
    value(sum(sell[i,j]*barge_sellBin[3,i,j] for i in ie, j=1:21) ))
    println("PA sale for the third tear:",
    value(sum(sell[i,j]*barge_sellBin[3,i,j] for i in pa, j=1:21) ))
    println("KI sale for the third tear:",
    value(sum(sell[i,j]*barge_sellBin[3,i,j] for i in ki, j=1:21) ))


else
    println("No optimal solution available")
end

