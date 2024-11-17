name = "Alice"
age = 30
city = "Beijing"
job = "Engineer"

# 定义一个格式化的用户信息模板
user_info_template = """
姓名: {0}
年龄: {1}
城市: {2}
职业: {3}
"""

# 可以重复使用这个模板
user1_info = user_info_template.format(name, age, city, job)
print(user1_info)