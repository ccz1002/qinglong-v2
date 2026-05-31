"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Menu = void 0;
const sequelize_1 = require("sequelize");
const index_1 = require("./index");
class Menu extends sequelize_1.Model {
}
exports.Menu = Menu;
Menu.init({
    id: {
        type: sequelize_1.DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true,
    },
    name: {
        type: sequelize_1.DataTypes.STRING,
        allowNull: false,
    },
    path: {
        type: sequelize_1.DataTypes.STRING,
        allowNull: false,
    },
    component: {
        type: sequelize_1.DataTypes.STRING,
        allowNull: false,
        defaultValue: '',
    },
    title: {
        type: sequelize_1.DataTypes.STRING,
        allowNull: false,
    },
    icon: {
        type: sequelize_1.DataTypes.STRING,
        allowNull: false,
        defaultValue: '',
    },
    parentId: {
        type: sequelize_1.DataTypes.INTEGER,
        allowNull: true,
        defaultValue: null,
    },
    sort: {
        type: sequelize_1.DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0,
    },
    isHide: {
        type: sequelize_1.DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false,
    },
    keepAlive: {
        type: sequelize_1.DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: true,
    },
    roles: {
        type: sequelize_1.DataTypes.STRING,
        allowNull: false,
        defaultValue: '["R_ADMIN"]',
    },
    link: {
        type: sequelize_1.DataTypes.STRING,
        allowNull: true,
        defaultValue: null,
    },
    createdAt: {
        type: sequelize_1.DataTypes.DATE,
        allowNull: false,
        defaultValue: sequelize_1.DataTypes.NOW,
    },
    updatedAt: {
        type: sequelize_1.DataTypes.DATE,
        allowNull: false,
        defaultValue: sequelize_1.DataTypes.NOW,
    },
}, {
    sequelize: index_1.sequelize,
    tableName: 'Menus',
    timestamps: true,
});
//# sourceMappingURL=menu.js.map