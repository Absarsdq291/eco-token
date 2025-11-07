const hardhat = require("hardhat");

const data = process.env.DATA_EXECUTE;
const value = hardhat.ethers.toBigInt(process.env.VALUE_EXECUTE || 0);

module.exports = {
    data,
    value
};
