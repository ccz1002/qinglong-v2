"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const child_process_1 = require("child_process");
const path_1 = require("path");
const route = (0, express_1.Router)();
const LOG_FILE = '/tmp/ql-update.log';
const SCRIPT = path_1.join(__dirname, '..', 'update-v2.sh');

exports.default = (app) => {
    app.use('/update-v2', route);

    // 触发更新
    route.post('/start', async (req, res) => {
        try {
            // 清空旧日志
            require('fs').writeFileSync(LOG_FILE, '');
            // 后台执行更新脚本
            (0, child_process_1.spawn)('bash', [SCRIPT], {
                detached: true,
                stdio: 'ignore'
            }).unref();
            res.send({ code: 200, message: '更新已启动' });
        } catch (e) {
            res.send({ code: 500, message: e.message });
        }
    });

    // 查询进度
    route.get('/progress', (req, res) => {
        try {
            const fs = require('fs');
            if (fs.existsSync(LOG_FILE)) {
                const log = fs.readFileSync(LOG_FILE, 'utf-8');
                const done = log.includes('DONE');
                const error = log.includes('ERROR');
                res.send({ code: 200, data: { log, done, error } });
            } else {
                res.send({ code: 200, data: { log: '等待启动...', done: false, error: false } });
            }
        } catch (e) {
            res.send({ code: 500, message: e.message });
        }
    });
};
