"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MenuService = void 0;
const typedi_1 = require("typedi");
const menu_1 = require("../data/menu");
let MenuService = class MenuService {
    /**
     * 获取菜单列表 (树形结构, 符合 Art Design Pro 后端模式格式)
     */
    async list() {
        const menus = await menu_1.Menu.findAll({ order: [['sort', 'ASC']] });
        return this.buildTree(menus.map((m) => m.toJSON()), null);
    }
    /**
     * 创建菜单
     */
    async create(data) {
        return menu_1.Menu.create({
            name: data.name,
            path: data.path,
            component: data.component || '',
            title: data.title,
            icon: data.icon || '',
            parentId: data.parentId || null,
            sort: data.sort || 0,
            isHide: data.isHide || false,
            keepAlive: data.keepAlive !== false,
            roles: JSON.stringify(data.roles || ['R_ADMIN']),
            link: data.link || null,
        });
    }
    /**
     * 更新菜单
     */
    async update(id, data) {
        const updateData = {};
        if (data.name !== undefined)
            updateData.name = data.name;
        if (data.path !== undefined)
            updateData.path = data.path;
        if (data.component !== undefined)
            updateData.component = data.component;
        if (data.title !== undefined)
            updateData.title = data.title;
        if (data.icon !== undefined)
            updateData.icon = data.icon;
        if (data.parentId !== undefined)
            updateData.parentId = data.parentId || null;
        if (data.sort !== undefined)
            updateData.sort = data.sort;
        if (data.isHide !== undefined)
            updateData.isHide = data.isHide;
        if (data.keepAlive !== undefined)
            updateData.keepAlive = data.keepAlive;
        if (data.roles !== undefined)
            updateData.roles = JSON.stringify(data.roles);
        if (data.link !== undefined)
            updateData.link = data.link || null;
        await menu_1.Menu.update(updateData, { where: { id } });
    }
    /**
     * 删除菜单
     */
    async remove(id) {
        // 先删除子菜单
        await menu_1.Menu.destroy({ where: { parentId: id } });
        await menu_1.Menu.destroy({ where: { id } });
    }
    /**
     * 构建树形结构, 适配 Art Design Pro AppRouteRecord 格式
     */
    buildTree(menus, parentId) {
        return menus
            .filter((m) => m.parentId === parentId)
            .map((menu) => {
            const children = this.buildTree(menus, menu.id);
            const result = {
                id: menu.id,
                name: menu.name,
                path: menu.path,
                component: menu.component || '',
                meta: Object.assign(Object.assign({ title: menu.title, icon: menu.icon || '', keepAlive: menu.keepAlive !== false, isHide: menu.isHide || false }, (menu.link ? { link: menu.link } : {})), (menu.roles ? { roles: JSON.parse(menu.roles) } : {})),
            };
            if (children.length > 0) {
                result.children = children;
            }
            return result;
        });
    }
};
exports.MenuService = MenuService;
exports.MenuService = MenuService = __decorate([
    (0, typedi_1.Service)()
], MenuService);
//# sourceMappingURL=menu.js.map