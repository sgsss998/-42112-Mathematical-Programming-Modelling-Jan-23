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
fixedcost = [100,300,500,500,700]
initialcap = [100,90,100,150,80]
increcap = [1.5,1.5,2,2,2]
procap = [1.5*100,1.5*90,2*100,2*150,2*80]
#demandgrowth = [1.01,1.008,1.015,1.015,1.02,1.025,1.03,1.035]
demandgrowth = [1.01 1.01 1.01 1.01 1.008 1.008 1.008 1.008 
1.015 1.015 1.015 1.015 1.015 1.015 1.015 1.015
1.02 1.02 1.02 1.02  1.025 1.025 1.025 1.025
1.03 1.03 1.03 1.03 1.035 1.035 1.035 1.035]

discountfac = 0.95

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


# Model
A = Model(HiGHS.Optimizer)

#variables
@variable(A,barge_buyBin[p=1:6,m=1:61],Bin)   #定义船只的数量，购买原材料的船只数量
@variable(A,barge_buyBiny2[p=1:6,m=1:61],Bin)
@variable(A,barge_buyBiny3[p=1:6,m=1:61],Bin)
@variable(A,barge_buy[p=1:6]>=0,Int)
@variable(A,barge_buyy2[p=1:6]>=0,Int)
@variable(A,barge_buyy3[p=1:6]>=0,Int)
@variable(A,barge_sellBin[p=1:32,m=1:21],Bin)
@variable(A,barge_sellBiny2[p=1:32,m=1:21],Bin)
@variable(A,barge_sellBiny3[p=1:32,m=1:21],Bin)
@variable(A,barge_sell[p=1:32]>=0,Int) #定义船只的数量，售卖产品到各地的船只数量
@variable(A,barge_selly2[p=1:32]>=0,Int)
@variable(A,barge_selly3[p=1:32]>=0,Int)
@variable(A,woodproduct[1:5]>=0)
@variable(A,woodproducty2[1:5]>=0)
@variable(A,woodproducty3[1:5]>=0)
@variable(A,paperproduct[1:3]>=0)
@variable(A,paperproducty2[1:3]>=0)
@variable(A,paperproducty3[1:3]>=0)
#@variable(A,whethertosell[p=1:8,j=1:4],Bin)

@variable(A,rawremain[1:6]>=0)
@variable(A,rawremainy2[1:6]>=0)
@variable(A,rawremainy3[1:6]>=0)
#@variable(A,whethertobuy[1:6],Bin)
#@variable(A,whetherpro1[1:3],Bin)
#@variable(A,noraw[i=1:6]>=0)
#@variable(A,nopro[p=1:8,a=1:4]>=0)
@variable(A,incre[t=1:2,mill=1:5]>=0)


#objective
#总利润=收入-成本
#成本 = 采购成本 + 生产成本
#采购成本 = sum (alpha + beta * h) * h
#生产成本木头 = sum woodproduct[i]*c[i] for i=1:5
#生产成本纸浆 = sum paperproduct[i]*c[i] for i=1:3
#收入 = 销售收入 + 原料回收收入
#原料回收收入 = sum numberrawmaterialremain[i] * alpha[i] for i=1:6
#销售收入 = sum (r - epsilon * sellhowmuch)*sellhowmuch
@objective(A,Max,sum(rawremain[i]*timber_assort[i][1] for i=1:6) + 
sum(sell[i,j]*barge_sellBin[i,j] for i=1:32,j=1:21) -   #销售收入
sum(cost[i,j]*barge_buyBin[i,j] for i=1:6,j=1:61) -    #原材料采购成本
sum(woodproduct[p]*woodproductmatrix[p,1] for p=1:5) - 
sum(paperproduct[p]*paperproductmatrix[p,1] for p=1:3) + 
sum(woodproduct[p]*0.2*40 for p=1:5            ) -
sum(initialcap[i]*fixedcost[i] for i=1:5   )    -           # basic fixed cost for year 1
sum(incre[1,i]*fixedcost[i] for i=1:5) +     # 第一年新增的固定成本 extra fixed cost for year 1 (if expand capacity)
###################################################### 至此第一年的利润计算结束，下面算t=2第二年的利润
(
sum(rawremainy2[i]*timber_assort[i][1] for i=1:6) + 
sum(sell[i,j]*barge_sellBiny2[i,j]/demandgrowth[i] for i=1:32,j=1:21) -
sum(cost[i,j]*barge_buyBiny2[i,j] for i=1:6,j=1:61) -
sum(woodproducty2[p]*woodproductmatrix[p,1] for p=1:5) - 
sum(paperproducty2[p]*paperproductmatrix[p,1] for p=1:3) + 
sum(woodproducty2[p]*0.2*40 for p=1:5            ) -
sum(initialcap[i]*fixedcost[i] for i=1:5   )    -       #basic   
sum(incre[1,i]*fixedcost[i] for i=1:5)    -             #fixed cost for year 2
sum(incre[2,i]*fixedcost[i] for i=1:5)                  #第二年新增的固定成本
) * discountfac      +           #把第二年的利润折现
#################################################下面开始算第三年的利润
(
sum(rawremainy3[i]*timber_assort[i][1] for i=1:6) + 
sum(sell[i,j]*barge_sellBiny3[i,j]/demandgrowth[i]/demandgrowth[i] for i=1:32,j=1:21) -
sum(cost[i,j]*barge_buyBiny3[i,j] for i=1:6,j=1:61) -
sum(woodproducty3[p]*woodproductmatrix[p,1] for p=1:5) - 
sum(paperproducty3[p]*paperproductmatrix[p,1] for p=1:3) + 
sum(woodproducty3[p]*0.2*40 for p=1:5            ) -
sum(initialcap[i]*fixedcost[i] for i=1:5   )    -        
sum(incre[1,i]*fixedcost[i] for i=1:5)    -             
sum(incre[2,i]*fixedcost[i] for i=1:5)                  
) * discountfac * discountfac      



)

#constraint
@constraint(A,[p=1:32],sum(barge_sellBin[p,m] for m=1:21)==1)
@constraint(A,[p=1:6],sum(barge_buyBin[p,m] for m=1:61)==1)
@constraint(A,[p=1:6],barge_buy[p] == (sum(barge_buyBin[p,m]*m for m=1:61)-1))
@constraint(A,[p=1:32],barge_sell[p] == (sum(barge_sellBin[p,m]*m for m=1:21)-1))
#year2
@constraint(A,[p=1:32],sum(barge_sellBiny2[p,m] for m=1:21)==1)
@constraint(A,[p=1:6],sum(barge_buyBiny2[p,m] for m=1:61)==1)
@constraint(A,[p=1:6],barge_buyy2[p] == (sum(barge_buyBiny2[p,m]*m for m=1:61)-1))
@constraint(A,[p=1:32],barge_selly2[p] == (sum(barge_sellBiny2[p,m]*m for m=1:21)-1))
#year3
@constraint(A,[p=1:32],sum(barge_sellBiny3[p,m] for m=1:21)==1)
@constraint(A,[p=1:6],sum(barge_buyBiny3[p,m] for m=1:61)==1)
@constraint(A,[p=1:6],barge_buyy3[p] == (sum(barge_buyBiny3[p,m]*m for m=1:61)-1))
@constraint(A,[p=1:32],barge_selly3[p] == (sum(barge_sellBiny3[p,m]*m for m=1:21)-1))

@constraint(A,incre[1,1]<=50)
@constraint(A,incre[1,2]<=45)
@constraint(A,incre[1,3]<=100)
@constraint(A,incre[1,4]<=150)
@constraint(A,incre[1,5]<=80)
@constraint(A,incre[2,1]<=50-incre[1,1])
@constraint(A,incre[2,2]<=45-incre[1,2])
@constraint(A,incre[2,3]<=100-incre[1,3])
@constraint(A,incre[2,4]<=150-incre[1,4])
@constraint(A,incre[2,5]<=80-incre[1,5])







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
@constraint(A,sum(woodproduct[p] for p=1:3)<=100)
@constraint(A,sum(woodproduct[p] for p=4:5)<=90)
@constraint(A,paperproduct[1]<=100)
@constraint(A,paperproduct[2]<=150)
@constraint(A,paperproduct[3]<=80)
#容量要求(for year 2 )
@constraint(A,sum(woodproducty2[p] for p=1:3)<=100+incre[1,1])
@constraint(A,sum(woodproducty2[p] for p=4:5)<=90+incre[1,2])
@constraint(A,paperproducty2[1]<=100+incre[1,3])
@constraint(A,paperproducty2[2]<=150+incre[1,4])
@constraint(A,paperproducty2[3]<=80+incre[1,5])
#容量要求(for year 3 )
@constraint(A,sum(woodproducty3[p] for p=1:3)<=100+incre[1,1]+incre[2,1])
@constraint(A,sum(woodproducty3[p] for p=4:5)<=90+incre[1,2]+incre[2,2])
@constraint(A,paperproducty3[1]<=100+incre[1,3]+incre[2,3])
@constraint(A,paperproducty3[2]<=150+incre[1,4]+incre[2,4])
@constraint(A,paperproducty3[3]<=80+incre[1,5]+incre[2,5])


#生产方程式（木头）
@constraint(A,woodproduct[1]<=barge_buy[1]*10*0.5)
@constraint(A,woodproduct[2]<=barge_buy[2]*10*0.5)
@constraint(A,woodproduct[3]<=barge_buy[3]*10*0.5)
@constraint(A,woodproduct[4]<=barge_buy[2]*10/2.8)
@constraint(A,woodproduct[5]<=barge_buy[3]*10/2.8)
#生产方程式（木头）year 2
@constraint(A,woodproducty2[1]<=barge_buyy2[1]*10*0.5)
@constraint(A,woodproducty2[2]<=barge_buyy2[2]*10*0.5)
@constraint(A,woodproducty2[3]<=barge_buyy2[3]*10*0.5)
@constraint(A,woodproducty2[4]<=barge_buyy2[2]*10/2.8)
@constraint(A,woodproducty2[5]<=barge_buyy2[3]*10/2.8)
#生产方程式（木头） year 3
@constraint(A,woodproducty3[1]<=barge_buyy3[1]*10*0.5)
@constraint(A,woodproducty3[2]<=barge_buyy3[2]*10*0.5)
@constraint(A,woodproducty3[3]<=barge_buyy3[3]*10*0.5)
@constraint(A,woodproducty3[4]<=barge_buyy3[2]*10/2.8)
@constraint(A,woodproducty3[5]<=barge_buyy3[3]*10/2.8)




#生产方程式（纸和纸浆）
@constraint(A,paperproduct[1]<=(woodproduct[1]*0.8+barge_buy[4]*10)/4.8)
@constraint(A,paperproduct[2]<= (woodproduct[3]*0.8+woodproduct[5]*1.6+barge_buy[6]*10)/4.2            )
@constraint(A,paperproduct[3]<= (woodproduct[2]*0.8+woodproduct[4]*1.6+barge_buy[5]*10)/1                               )
@constraint(A,paperproduct[3]<=    paperproduct[1]          /0.2   )
@constraint(A,paperproduct[3]<=   paperproduct[2]           /0.2   )
#生产方程式（纸和纸浆）year 2
@constraint(A,paperproducty2[1]<=(woodproducty2[1]*0.8+barge_buyy2[4]*10)/4.8)
@constraint(A,paperproducty2[2]<= (woodproducty2[3]*0.8+woodproducty2[5]*1.6+barge_buyy2[6]*10)/4.2            )
@constraint(A,paperproducty2[3]<= (woodproducty2[2]*0.8+woodproducty2[4]*1.6+barge_buyy2[5]*10)/1                               )
@constraint(A,paperproducty2[3]<=    paperproducty2[1]          /0.2   )
@constraint(A,paperproducty2[3]<=   paperproducty2[2]           /0.2   )
#生产方程式（纸和纸浆）year 3
@constraint(A,paperproducty3[1]<=(woodproducty3[1]*0.8+barge_buyy3[4]*10)/4.8)
@constraint(A,paperproducty3[2]<= (woodproducty3[3]*0.8+woodproducty3[5]*1.6+barge_buyy3[6]*10)/4.2            )
@constraint(A,paperproducty3[3]<= (woodproducty3[2]*0.8+woodproducty3[4]*1.6+barge_buyy3[5]*10)/1                               )
@constraint(A,paperproducty3[3]<=    paperproducty3[1]          /0.2   )
@constraint(A,paperproducty3[3]<=   paperproducty3[2]           /0.2   )

#剩下的原材料数量约束
@constraint(A,rawremain[1] <= barge_buy[1]*10-woodproduct[1]*2  )
@constraint(A,rawremain[2] <= barge_buy[2]*10-woodproduct[2]*2-woodproduct[4]*2.8)
@constraint(A,rawremain[3] <= barge_buy[3]*10-woodproduct[3]*2-woodproduct[5]*2.8)
@constraint(A,rawremain[4] <= barge_buy[4]*10+woodproduct[1]*0.8-paperproduct[1]*4.8)
@constraint(A,rawremain[5] <= barge_buy[5]*10+woodproduct[2]*0.8+woodproduct[4]*1.6-paperproduct[3]*1)
@constraint(A,rawremain[6] <= barge_buy[6]*10+woodproduct[3]*0.8+woodproduct[5]*1.6-paperproduct[2]*4.2)
#剩下的原材料数量约束 year 2
@constraint(A,rawremainy2[1] <= barge_buyy2[1]*10-woodproducty2[1]*2  )
@constraint(A,rawremainy2[2] <= barge_buyy2[2]*10-woodproducty2[2]*2-woodproducty2[4]*2.8)
@constraint(A,rawremainy2[3] <= barge_buyy2[3]*10-woodproducty2[3]*2-woodproducty2[5]*2.8)
@constraint(A,rawremainy2[4] <= barge_buyy2[4]*10+woodproducty2[1]*0.8-paperproducty2[1]*4.8)
@constraint(A,rawremainy2[5] <= barge_buyy2[5]*10+woodproducty2[2]*0.8+woodproducty2[4]*1.6-paperproducty2[3]*1)
@constraint(A,rawremainy2[6] <= barge_buyy2[6]*10+woodproducty2[3]*0.8+woodproducty2[5]*1.6-paperproducty2[2]*4.2)
#剩下的原材料数量约束 year 3
@constraint(A,rawremainy3[1] <= barge_buyy3[1]*10-woodproducty3[1]*2  )
@constraint(A,rawremainy3[2] <= barge_buyy3[2]*10-woodproducty3[2]*2-woodproducty3[4]*2.8)
@constraint(A,rawremainy3[3] <= barge_buyy3[3]*10-woodproducty3[3]*2-woodproducty3[5]*2.8)
@constraint(A,rawremainy3[4] <= barge_buyy3[4]*10+woodproducty3[1]*0.8-paperproducty3[1]*4.8)
@constraint(A,rawremainy3[5] <= barge_buyy3[5]*10+woodproducty3[2]*0.8+woodproducty3[4]*1.6-paperproducty3[3]*1)
@constraint(A,rawremainy3[6] <= barge_buyy3[6]*10+woodproducty3[3]*0.8+woodproducty3[5]*1.6-paperproducty3[2]*4.2)

#生产量 >= 销售量
@constraint(A,woodproduct[1] >= barge_sell[1]*10 + barge_sell[2]*10 + barge_sell[3]*10 + barge_sell[4]*10)
@constraint(A,woodproduct[2] >= barge_sell[5]*10 + barge_sell[6]*10 + barge_sell[7]*10 + barge_sell[8]*10)
@constraint(A,woodproduct[3] >= barge_sell[9]*10 + barge_sell[10]*10 + barge_sell[11]*10 + barge_sell[12]*10)
@constraint(A,woodproduct[4] >= barge_sell[13]*10 + barge_sell[14]*10 + barge_sell[15]*10 + barge_sell[16]*10)
@constraint(A,woodproduct[5] >= barge_sell[17]*10 + barge_sell[18]*10 + barge_sell[19]*10 + barge_sell[20]*10)
@constraint(A, paperproduct[1]-0.2*paperproduct[3] >= barge_sell[21]*10 + barge_sell[22]*10 + barge_sell[23]*10 + barge_sell[24]*10)
@constraint(A, paperproduct[2]-0.2*paperproduct[3] >= barge_sell[25]*10 + barge_sell[26]*10 + barge_sell[27]*10 + barge_sell[28]*10)
@constraint(A, paperproduct[3] >= barge_sell[29]*10 + barge_sell[30]*10 + barge_sell[31]*10 + barge_sell[32]*10)
#生产量 >= 销售量 year2
@constraint(A,woodproducty2[1] >= barge_selly2[1]*10 + barge_selly2[2]*10 + barge_selly2[3]*10 + barge_selly2[4]*10)
@constraint(A,woodproducty2[2] >= barge_selly2[5]*10 + barge_selly2[6]*10 + barge_selly2[7]*10 + barge_selly2[8]*10)
@constraint(A,woodproducty2[3] >= barge_selly2[9]*10 + barge_selly2[10]*10 + barge_selly2[11]*10 + barge_selly2[12]*10)
@constraint(A,woodproducty2[4] >= barge_selly2[13]*10 + barge_selly2[14]*10 + barge_selly2[15]*10 + barge_selly2[16]*10)
@constraint(A,woodproducty2[5] >= barge_selly2[17]*10 + barge_selly2[18]*10 + barge_selly2[19]*10 + barge_selly2[20]*10)
@constraint(A, paperproducty2[1]-0.2*paperproducty2[3] >= barge_selly2[21]*10 + barge_selly2[22]*10 + barge_selly2[23]*10 + barge_selly2[24]*10)
@constraint(A, paperproducty2[2]-0.2*paperproducty2[3] >= barge_selly2[25]*10 + barge_selly2[26]*10 + barge_selly2[27]*10 + barge_selly2[28]*10)
@constraint(A, paperproducty2[3] >= barge_selly2[29]*10 + barge_selly2[30]*10 + barge_selly2[31]*10 + barge_selly2[32]*10)
#生产量 >= 销售量 year3
@constraint(A,woodproducty3[1] >= barge_selly3[1]*10 + barge_selly3[2]*10 + barge_selly3[3]*10 + barge_selly3[4]*10)
@constraint(A,woodproducty3[2] >= barge_selly3[5]*10 + barge_selly3[6]*10 + barge_selly3[7]*10 + barge_selly3[8]*10)
@constraint(A,woodproducty3[3] >= barge_selly3[9]*10 + barge_selly3[10]*10 + barge_selly3[11]*10 + barge_selly3[12]*10)
@constraint(A,woodproducty3[4] >= barge_selly3[13]*10 + barge_selly3[14]*10 + barge_selly3[15]*10 + barge_selly3[16]*10)
@constraint(A,woodproducty3[5] >= barge_selly3[17]*10 + barge_selly3[18]*10 + barge_selly3[19]*10 + barge_selly3[20]*10)
@constraint(A, paperproducty3[1]-0.2*paperproducty3[3] >= barge_selly3[21]*10 + barge_selly3[22]*10 + barge_selly3[23]*10 + barge_selly3[24]*10)
@constraint(A, paperproducty3[2]-0.2*paperproducty3[3] >= barge_selly3[25]*10 + barge_selly3[26]*10 + barge_selly3[27]*10 + barge_selly3[28]*10)
@constraint(A, paperproducty3[3] >= barge_selly3[29]*10 + barge_selly3[30]*10 + barge_selly3[31]*10 + barge_selly3[32]*10)




print(A)
optimize!(A)


println("Termination status: $(termination_status(A))")
if termination_status(A) == MOI.OPTIMAL
    println("Optimal objective value: $(objective_value(A))")
    println("####################################################################
YEAR 1")
    for p=1:5
        println("product[", p,"] : ",value(woodproduct[p]))
    end
    for p=1:3
        println("product[", p+5,"] : ",value(paperproduct[p]))
    end
    for t=1:6
        println("buy[",t,"] : ",value(barge_buy[t]))
    end
else
    println("No optimal solution available")
end

println("####################################################################
YEAR 2")
for p=1:5
    println("product[", p,"] : ",value(woodproducty2[p]))
end
for p=1:3
    println("product[", p+5,"] : ",value(paperproducty2[p]))
end
for t=1:6
    println("buy[",t,"] : ",value(barge_buyy2[t]))
end
println("####################################################################
YEAR 3")
for p=1:5
    println("product[", p,"] : ",value(woodproducty3[p]))
end
for p=1:3
    println("product[", p+5,"] : ",value(paperproducty3[p]))
end
for t=1:6
    println("buy[",t,"] : ",value(barge_buyy3[t]))
end

println(value(sum(rawremain[i]*timber_assort[i][1] for i=1:6) + 
sum(sell[i,j]*barge_sellBin[i,j] for i=1:32,j=1:21) -   #销售收入
sum(cost[i,j]*barge_buyBin[i,j] for i=1:6,j=1:61) -    #原材料采购成本
sum(woodproduct[p]*woodproductmatrix[p,1] for p=1:5) - 
sum(paperproduct[p]*paperproductmatrix[p,1] for p=1:3) + 
sum(woodproduct[p]*0.2*40 for p=1:5            ) -
sum(initialcap[i]*fixedcost[i] for i=1:5   )    -           # basic fixed cost for year 1
sum(incre[1,i]*fixedcost[i] for i=1:5)))

println(value((
    sum(rawremainy2[i]*timber_assort[i][1] for i=1:6) + 
    sum(sell[i,j]*barge_sellBiny2[i,j]/demandgrowth[i] for i=1:32,j=1:21) -
    sum(cost[i,j]*barge_buyBiny2[i,j] for i=1:6,j=1:61) -
    sum(woodproducty2[p]*woodproductmatrix[p,1] for p=1:5) - 
    sum(paperproducty2[p]*paperproductmatrix[p,1] for p=1:3) + 
    sum(woodproducty2[p]*0.2*40 for p=1:5            ) -
    sum(initialcap[i]*fixedcost[i] for i=1:5   )    -       #basic   
    sum(incre[1,i]*fixedcost[i] for i=1:5)    -             #fixed cost for year 2
    sum(incre[2,i]*fixedcost[i] for i=1:5)                  #第二年新增的固定成本
    ) * discountfac))

println(value((
    sum(rawremainy3[i]*timber_assort[i][1] for i=1:6) + 
    sum(sell[i,j]*barge_sellBiny3[i,j]/demandgrowth[i]/demandgrowth[i] for i=1:32,j=1:21) -
    sum(cost[i,j]*barge_buyBiny3[i,j] for i=1:6,j=1:61) -
    sum(woodproducty3[p]*woodproductmatrix[p,1] for p=1:5) - 
    sum(paperproducty3[p]*paperproductmatrix[p,1] for p=1:3) + 
    sum(woodproducty3[p]*0.2*40 for p=1:5            ) -
    sum(initialcap[i]*fixedcost[i] for i=1:5   )    -        
    sum(incre[1,i]*fixedcost[i] for i=1:5)    -             
    sum(incre[2,i]*fixedcost[i] for i=1:5)                  
    ) * discountfac * discountfac      ))

for y=1:2
    for f=1:5
        println("year[", y,"] : ",value(incre[y,f]))
    end
end

value(barge_sell[1])
value(sum(barge_selly3[i] for i=1:32))
value((barge_sell[1]+barge_sell[5]+barge_sell[9]+barge_sell[13]+barge_sell[17]+barge_sell[21]+barge_sell[25]+barge_sell[29])/45)
################ Year 1
# For EU:
value((barge_sell[1]+barge_sell[5]+barge_sell[9]+barge_sell[13]+barge_sell[17]+barge_sell[21]+barge_sell[25]+barge_sell[29])/45)
# For IE
value((barge_sell[2]+barge_sell[6]+barge_sell[10]+barge_sell[14]+barge_sell[18]+barge_sell[22]+barge_sell[26]+barge_sell[30])/45)
# For PA
value((barge_sell[3]+barge_sell[7]+barge_sell[11]+barge_sell[15]+barge_sell[19]+barge_sell[23]+barge_sell[27]+barge_sell[31])/45)
# For KI
value((barge_sell[4]+barge_sell[8]+barge_sell[12]+barge_sell[16]+barge_sell[20]+barge_sell[24]+barge_sell[28]+barge_sell[32])/45)

################ Year 2
# For EU:
value((barge_selly2[1]+barge_selly2[5]+barge_selly2[9]+barge_selly2[13]+barge_selly2[17]+barge_selly2[21]+barge_selly2[25]+barge_selly2[29])/48)
# For IE
value((barge_selly2[2]+barge_selly2[6]+barge_selly2[10]+barge_selly2[14]+barge_selly2[18]+barge_selly2[22]+barge_selly2[26]+barge_selly2[30])/48)
# For PA
value((barge_selly2[3]+barge_selly2[7]+barge_selly2[11]+barge_selly2[15]+barge_selly2[19]+barge_selly2[23]+barge_selly2[27]+barge_selly2[31])/48)
# For KI
value((barge_selly2[4]+barge_selly2[8]+barge_selly2[12]+barge_selly2[16]+barge_selly2[20]+barge_selly2[24]+barge_selly2[28]+barge_selly2[32])/48)

################ Year 3
# For EU:
value((barge_selly3[1]+barge_selly3[5]+barge_selly3[9]+barge_selly3[13]+barge_selly3[17]+barge_selly3[21]+barge_selly3[25]+barge_selly3[29])/48)
# For IE
value((barge_selly3[2]+barge_selly3[6]+barge_selly3[10]+barge_selly3[14]+barge_selly3[18]+barge_selly3[22]+barge_selly3[26]+barge_selly3[30])/48)
# For PA
value((barge_selly3[3]+barge_selly3[7]+barge_selly3[11]+barge_selly3[15]+barge_selly3[19]+barge_selly3[23]+barge_selly3[27]+barge_selly3[31])/48)
# For KI
value((barge_selly3[4]+barge_selly3[8]+barge_selly3[12]+barge_selly3[16]+barge_selly3[20]+barge_selly3[24]+barge_selly3[28]+barge_selly3[32])/48)