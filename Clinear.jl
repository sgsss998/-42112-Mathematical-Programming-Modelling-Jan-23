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
DISK = 0.95
productioncap1 = 100 #MAS, KUS, KOS
productioncap2 = 90  #KUV KOV
productioncap3 = 100 #HSEL
productioncap4 = 150 #LSEL
productioncap5 = 80
cap = [100 90 100 150 80]
productionincrease_cap = [1.5 1.5 2 2 2]
fixedcost =[100 300 300 500 700]
demandgrowth = [1.01 1.01 1.01 1.01 1.008 1.008 1.008 1.008 
1.015 1.015 1.015 1.015 1.015 1.015 1.015 1.015
1.02 1.02 1.02 1.02  1.025 1.025 1.025 1.025
1.03 1.03 1.03 1.03 1.035 1.035 1.035 1.035]
year = ["1","2","3"]
Y = length(year)
discount = [1, DISK, DISK*DISK]

#Exercise c
scenario = ["1", "2", "3", "4"]
S = length(scenario)
ratio = [1 1.05 1.07; 1 1.05 0.95; 1 0.95 1.05; 1 0.95 0.93]#R[s,y]
probability = [1/4 1/4 1/4 1/4]

# Model
A = Model(HiGHS.Optimizer)

#variables
@variable(A,barge_buyBin[1:S,1:Y,1:6,1:61],Bin)   #定义船只的数量，购买原材料的船只数量
@variable(A,barge_buy[1:S,1:Y,1:6]>=0,Int)

@variable(A,woodproduct[1:S,1:Y,1:5]>=0)
@variable(A,paperproduct[1:S,1:Y,1:3]>=0)
@variable(A,barge_sellBin[1:S,1:Y,1:32,1:21],Bin)
@variable(A,barge_sell[1:S,1:Y,1:32]>=0,Int) #定义船只的数量，售卖产品到各地的船只数量
@variable(A,rawremain[1:S,1:Y,1:6]>=0)

@variable(A, r1[1:S,1:5]>=1)#
@variable(A, r2[1:S,1:5]>=1)
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
@objective(A,Max,sum((sum(rawremain[s,y,i]*timber_assort[i,1]*discount[y] for y=1:Y,i=1:6) + 
ratio[s,1]*sum(sell[i,j]*barge_sellBin[s,1,i,j] for i=1:32,j=1:21)+
ratio[s,2]*sum(sell[i,j]*barge_sellBin[s,2,i,j]/demandgrowth[i] for i=1:32,j=1:21)*DISK+
ratio[s,3]*sum(sell[i,j]*barge_sellBin[s,3,i,j]/(demandgrowth[i]*demandgrowth[i]) for i=1:32,j=1:21)*DISK*DISK-   #销售收入
sum(cost[i,j]*barge_buyBin[s,y,i,j]*discount[y] for y=1:Y,i=1:6,j=1:61) -    #原材料采购成本
sum(woodproduct[s,y,p]*woodproductmatrix[p,1]*discount[y] for y=1:Y,p=1:5) - 
sum(paperproduct[s,y,p]*paperproductmatrix[p,1]*discount[y] for y=1:Y,p=1:3) + 
sum(woodproduct[s,y,p]*0.2*40*discount[y] for y=1:Y,p=1:5 ) #燃料回收
-sum(cap[p]*fixedcost[p]*r1[s,p] for p=1:5)
-sum(cap[p]*fixedcost[p]*r2[s,p] for p=1:5)*DISK
-sum(cap[p]*fixedcost[p]*r2[s,p] for p=1:5)*DISK*DISK)*probability[s]
for s=1:S) 
)
#constraint
#@constraint(A,[i=1:6],noraw[i]*10 <= h[i])
#@constraint(A,[p=1:8,a=1:4],nopro[p,a]*10 <= q[p,a] )
@constraint(A,[s=1:S,y=1:Y,p=1:32],sum(barge_sellBin[s,y,p,m] for m=1:21)==1)
@constraint(A,[s=1:S,y=1:Y,p=1:6],sum(barge_buyBin[s,y,p,m] for m=1:61)==1)
@constraint(A,[s=1:S,y=1:Y,p=1:6],barge_buy[s,y,p] == (sum(barge_buyBin[s,y,p,m]*m for m=1:61)-1))
@constraint(A,[s=1:S,y=1:Y,p=1:32],barge_sell[s,y,p] == (sum(barge_sellBin[s,y,p,m]*m for m=1:21)-1))
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
@constraint(A,[s=1:S],sum(woodproduct[s,1,p] for p=1:3)<=productioncap1)
@constraint(A,[s=1:S],sum(woodproduct[s,1,p] for p=4:5)<=productioncap2)
@constraint(A,[s=1:S],paperproduct[s,1,1]<=productioncap3)
@constraint(A,[s=1:S],paperproduct[s,1,2]<=productioncap4)
@constraint(A,[s=1:S],paperproduct[s,1,3]<=productioncap5)
#year2
@constraint(A,[s=1:S],sum(woodproduct[s,2,p] for p=1:3)<=productioncap1*r1[s,1])
@constraint(A,[s=1:S],sum(woodproduct[s,2,p] for p=4:5)<=productioncap2*r1[s,2])
@constraint(A,[s=1:S],paperproduct[s,2,1]<=productioncap3*r1[s,3])
@constraint(A,[s=1:S],paperproduct[s,2,2]<=productioncap4*r1[s,4])
@constraint(A,[s=1:S],paperproduct[s,2,3]<=productioncap5*r1[s,5])
#year3
@constraint(A,[s=1:S],sum(woodproduct[s,3,p] for p=1:3)<=productioncap1*r2[s,1])
@constraint(A,[s=1:S],sum(woodproduct[s,3,p] for p=4:5)<=productioncap2*r2[s,2])
@constraint(A,[s=1:S],paperproduct[s,3,1]<=productioncap3*r2[s,3])
@constraint(A,[s=1:S],paperproduct[s,3,2]<=productioncap4*r2[s,4])
@constraint(A,[s=1:S],paperproduct[s,3,3]<=productioncap5*r2[s,5])
#constraints of increase rates
@constraint(A,[s=1:S,p=1:5],r1[s,p] <= productionincrease_cap[p])
@constraint(A,[s=1:S,p=1:5],r2[s,p] <= productionincrease_cap[p])
@constraint(A,[s=1:S,p=1:5],r1[s,p] <= r2[s,p])

#生产方程式（木头）
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,1]<=barge_buy[s,y,1]*10*0.5)
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,2]<=barge_buy[s,y,2]*10*0.5)
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,3]<=barge_buy[s,y,3]*10*0.5)
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,4]<=barge_buy[s,y,2]*10/2.8)
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,5]<=barge_buy[s,y,3]*10/2.8)

#生产方程式（纸和纸浆）
@constraint(A,[s=1:S,y=1:Y],paperproduct[s,y,1]<=(woodproduct[s,y,1]*0.8+barge_buy[s,y,4]*10)/4.8)
@constraint(A,[s=1:S,y=1:Y],paperproduct[s,y,2]<= (woodproduct[s,y,3]*0.8+woodproduct[s,y,5]*1.6+barge_buy[s,y,6]*10)/4.2            )
@constraint(A,[s=1:S,y=1:Y],paperproduct[s,y,3]<= (woodproduct[s,y,2]*0.8+woodproduct[s,y,4]*1.6+barge_buy[s,y,5]*10)                             )
@constraint(A,[s=1:S,y=1:Y],paperproduct[s,y,3]<= paperproduct[s,y,1] /0.2)
@constraint(A,[s=1:S,y=1:Y],paperproduct[s,y,3]<= paperproduct[s,y,2] /0.2)



#剩下的原材料数量约束
@constraint(A,[s=1:S,y=1:Y],rawremain[s,y,1] <= barge_buy[s,y,1]*10-woodproduct[s,y,1]*2  )
@constraint(A,[s=1:S,y=1:Y],rawremain[s,y,2] <= barge_buy[s,y,2]*10-woodproduct[s,y,2]*2-woodproduct[s,y,4]*2.8)
@constraint(A,[s=1:S,y=1:Y],rawremain[s,y,3] <= barge_buy[s,y,3]*10-woodproduct[s,y,3]*2-woodproduct[s,y,5]*2.8)
@constraint(A,[s=1:S,y=1:Y],rawremain[s,y,4] <= barge_buy[s,y,4]*10+woodproduct[s,y,1]*0.8-paperproduct[s,y,1]*4.8)
@constraint(A,[s=1:S,y=1:Y],rawremain[s,y,5] <= barge_buy[s,y,5]*10+woodproduct[s,y,2]*0.8+woodproduct[s,y,4]*1.6-paperproduct[s,y,3]*1)
@constraint(A,[s=1:S,y=1:Y],rawremain[s,y,6] <= barge_buy[s,y,6]*10+woodproduct[s,y,3]*0.8+woodproduct[s,y,5]*1.6-paperproduct[s,y,2]*4.2)

#生产量 >= 销售量

@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,1] >= barge_sell[s,y,1]*10 + barge_sell[s,y,2]*10 + barge_sell[s,y,3]*10 + barge_sell[s,y,4]*10)
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,2] >= barge_sell[s,y,5]*10 + barge_sell[s,y,6]*10 + barge_sell[s,y,7]*10 + barge_sell[s,y,8]*10)
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,3] >= barge_sell[s,y,9]*10 + barge_sell[s,y,10]*10 + barge_sell[s,y,11]*10 + barge_sell[s,y,12]*10)
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,4] >= barge_sell[s,y,13]*10 + barge_sell[s,y,14]*10 + barge_sell[s,y,15]*10 + barge_sell[s,y,16]*10)
@constraint(A,[s=1:S,y=1:Y],woodproduct[s,y,5] >= barge_sell[s,y,17]*10 + barge_sell[s,y,18]*10 + barge_sell[s,y,19]*10 + barge_sell[s,y,20]*10)
@constraint(A,[s=1:S,y=1:Y],paperproduct[s,y,1]-0.2*paperproduct[s,y,3] >= barge_sell[s,y,21]*10 + barge_sell[s,y,22]*10 + barge_sell[s,y,23]*10 + barge_sell[s,y,24]*10)
@constraint(A,[s=1:S,y=1:Y],paperproduct[s,y,2]-0.2*paperproduct[s,y,3] >= barge_sell[s,y,25]*10 + barge_sell[s,y,26]*10 + barge_sell[s,y,27]*10 + barge_sell[s,y,28]*10)
@constraint(A,[s=1:S,y=1:Y],paperproduct[s,y,3] >= barge_sell[s,y,29]*10 + barge_sell[s,y,30]*10 + barge_sell[s,y,31]*10 + barge_sell[s,y,32]*10)


#@constraint(A,[p=1:5], woodproduct[p] >= sum(barge_sell[p,a]*10 for a=1:4))
#@constraint(A, paperproduct[1]-0.2*paperproduct[3] >= sum(barge_sell[6,a]*10 for a=1:4))
#@constraint(A, paperproduct[2]-0.2*paperproduct[3] >= sum(barge_sell[7,a]*10 for a=1:4))
#@constraint(A, paperproduct[3] >= sum(barge_sell[8,a]*10 for a=1:4))


#print(A)
optimize!(A)


println("Termination status: $(termination_status(A))")
if termination_status(A) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(A))")
    println("The average discounted profit for the first year:", 
    value(sum(sum(rawremain[s,1,i]*timber_assort[i,1]*discount[1] for i=1:6) + 
    ratio[s,1]*sum(sell[i,j]*barge_sellBin[s,1,i,j] for i=1:32,j=1:21)-
    sum(cost[i,j]*barge_buyBin[s,1,i,j]*discount[1] for i=1:6,j=1:61) -    #原材料采购成本
    sum(woodproduct[s,1,p]*woodproductmatrix[p,1]*discount[1] for p=1:5) - 
    sum(paperproduct[s,1,p]*paperproductmatrix[p,1]*discount[1] for p=1:3) + 
    sum(woodproduct[s,1,p]*0.2*40*discount[1] for p=1:5) #燃料回收
    -sum(cap[p]*fixedcost[p]*r1[s,p] for p=1:5))*probability[s] for s=1:S))

    println("The average discounted profit for the second year:", 
    value(sum(sum(rawremain[s,2,i]*timber_assort[i,1]*discount[2] for i=1:6) + 
    ratio[s,2]*sum(sell[i,j]*barge_sellBin[s,2,i,j]/demandgrowth[i] for i=1:32,j=1:21)*DISK-
    sum(cost[i,j]*barge_buyBin[s,2,i,j]*discount[2] for i=1:6,j=1:61) -    #原材料采购成本
    sum(woodproduct[s,2,p]*woodproductmatrix[p,1]*discount[2] for p=1:5) - 
    sum(paperproduct[s,2,p]*paperproductmatrix[p,1]*discount[2] for p=1:3) + 
    sum(woodproduct[s,2,p]*0.2*40*discount[2] for p=1:5) #燃料回收
    -sum(cap[p]*fixedcost[p]*r2[s,p] for p=1:5))*DISK*probability[s] for s=1:S))

    println("The average discounted profit for the third year:", 
    value(sum(sum(rawremain[s,3,i]*timber_assort[i,1]*discount[3] for i=1:6) + 
    ratio[s,3]*sum(sell[i,j]*barge_sellBin[s,3,i,j]/(demandgrowth[i]*demandgrowth[i]) for i=1:32,j=1:21)*DISK*DISK- 
    sum(cost[i,j]*barge_buyBin[s,3,i,j]*discount[3] for i=1:6,j=1:61) -    #原材料采购成本
    sum(woodproduct[s,3,p]*woodproductmatrix[p,1]*discount[3] for p=1:5) - 
    sum(paperproduct[s,3,p]*paperproductmatrix[p,1]*discount[3] for p=1:3) + 
    sum(woodproduct[s,3,p]*0.2*40*discount[3] for p=1:5) #燃料回收
    -sum(cap[p]*fixedcost[p]*r2[s,p] for p=1:5)*DISK*DISK)*probability[s] for s=1:S))
else
    println("No optimal solution available")
end

