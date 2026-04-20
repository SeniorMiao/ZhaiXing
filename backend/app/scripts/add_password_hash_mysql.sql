-- 若数据库在加入登录模块前已建过表，请执行一次（新建库可跳过）：
ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NULL;
