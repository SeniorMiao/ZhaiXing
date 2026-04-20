-- 老库补列：用户头像文件名（与 init_db 自动迁移等价）
ALTER TABLE users ADD COLUMN avatar_key VARCHAR(512) NULL;
