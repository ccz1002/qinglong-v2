"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const typedi_1 = require("typedi");
const menu_1 = require("../services/menu");
const route = (0, express_1.Router)();
exports.default = (app) => {
    app.use('/menus', route);
    // 获取菜单列表 (树形)
    route.get('/', async (req, res, next) => {
        try {
            const menuService = typedi_1.Container.get(menu_1.MenuService);
            const data = await menuService.list();
            res.send({ code: 200, data });
        }
        catch (error) {
            next(error);
        }
    });
    // 创建菜单
    route.post('/', async (req, res, next) => {
        try {
            const menuService = typedi_1.Container.get(menu_1.MenuService);
            const data = await menuService.create(req.body);
            res.send({ code: 200, data });
        }
        catch (error) {
            next(error);
        }
    });
    // 更新菜单
    route.put('/:id', async (req, res, next) => {
        try {
            const menuService = typedi_1.Container.get(menu_1.MenuService);
            await menuService.update(parseInt(req.params.id), req.body);
            res.send({ code: 200, data: {} });
        }
        catch (error) {
            next(error);
        }
    });
    // 删除菜单
    route.delete('/:id', async (req, res, next) => {
        try {
            const menuService = typedi_1.Container.get(menu_1.MenuService);
            await menuService.remove(parseInt(req.params.id));
            res.send({ code: 200, data: {} });
        }
        catch (error) {
            next(error);
        }
    });
};
//# sourceMappingURL=menu.js.map