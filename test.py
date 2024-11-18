import random

# 初始能量值（随机设置）
energy = -75.0
# 能量变化的阈值
threshold = 1e-6
# 初始变化量
delta = 1.0
# 迭代次数
iteration = 0

while abs(delta) > threshold:
    # 模拟新的能量变化，使用随机微小调整
    new_energy = energy + random.uniform(-1e-5, 1e-5)
    # 计算能量变化量
    delta = new_energy - energy
    # 更新能量值
    energy = new_energy
    iteration += 1
    # 打印每次迭代的信息
    print(f"迭代 {iteration}: 能量 = {energy:.8f}, 能量变化 = {delta:.8e}")

print("SCF 计算收敛完成！")
