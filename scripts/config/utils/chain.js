const hardhat = require("hardhat");

const { BIGINT_HUNDRED } = require("../common/constants");
const { BOOTSTRAP_STATE } = require("../common/states");
const { LOG_TYPE, TX_TYPE } = require("../common/types");

const { logNewLine } = require("./tools");

const fetchAdjustedFeeData = async ({ gasPriceIncrementFactorOverride, feeDataLogType }) => {
    const seperatorQuiet = feeDataLogType !== LOG_TYPE.VERBOSE;
    const primaryQuiet = feeDataLogType === LOG_TYPE.QUIET || feeDataLogType === LOG_TYPE.PRIMARY_QUIET;
    const secondaryQuiet = feeDataLogType === LOG_TYPE.QUIET || feeDataLogType === LOG_TYPE.SECONDARY_QUIET;

    let feeData;

    if (!secondaryQuiet) {
        // Forwarding without silencing logs.
        feeData = await fetchAdjustedFeeDataWithLogs(gasPriceIncrementFactorOverride);
    } else {
        // Saving console method.
        const log = console.log;

        // Overriding console method with no-op.
        console.log = () => {};

        try {
            // Forwarding with silenced logs.
            feeData = await fetchAdjustedFeeDataWithLogs(gasPriceIncrementFactorOverride);
        } finally {
            // Restoring console method.
            console.log = log;
        }
    }

    if (!seperatorQuiet) {
        logNewLine();
    }

    if (!primaryQuiet) {
        // Getting and logging gas price.
        const [gasPrice] = Object.values(feeData);
        const logGasPrice = Number(hardhat.ethers.formatUnits(gasPrice, "gwei"));
        console.log("Gas price:", logGasPrice, "gwei");
    }

    return feeData;
};

const fetchAdjustedFeeDataWithLogs = async (gasPriceIncrementFactorOverride) => {
    // Getting fee data.
    const feeData = await fetchFeeData();

    // Getting gas price increment factor.
    const gasPriceIncrementFactor = gasPriceIncrementFactorOverride || BOOTSTRAP_STATE.gasPriceIncrementFactor;

    // Getting gas price increment percentage.
    const gasPriceIncrementPercentage = hardhat.ethers.toBigInt(Math.round(gasPriceIncrementFactor * 100));

    // logging gas price increment factor.
    console.log("Gas price increment factor:", gasPriceIncrementFactor + "x");

    // Getting incremented gas price.
    const [firstKey] = Object.keys(feeData);
    feeData[firstKey] = (feeData[firstKey] * gasPriceIncrementPercentage) / BIGINT_HUNDRED;

    return feeData;
};

const fetchFeeData = async () => {
    // Getting gas price, max fee per gas and max priority fee per gas.
    const { gasPrice, maxFeePerGas, maxPriorityFeePerGas } = await hardhat.ethers.provider.getFeeData();

    const feeData = {};

    // Reading tx type from shared state.
    if (BOOTSTRAP_STATE.txType === TX_TYPE.TYPE0) {
        feeData.gasPrice = gasPrice;
    } else {
        feeData.maxFeePerGas = maxFeePerGas;
        feeData.maxPriorityFeePerGas = maxPriorityFeePerGas;
    }

    return feeData;
};

const fetchGasPrice = async () => {
    // Getting fee data.
    const feeData = await hardhat.ethers.provider.getFeeData();

    // Reading tx type from shared state.
    const gasPrice = BOOTSTRAP_STATE.txType === TX_TYPE.TYPE0 ? feeData.gasPrice : feeData.maxFeePerGas;

    return gasPrice;
};

const fetchLatestTransaction = async (toAddress, blocksToScan = 100) => {
    const currentBlock = await hardhat.ethers.provider.getBlockNumber();

    // Getting `from` signer.
    const [from] = await hardhat.ethers.getSigners();

    // Getting `from` address.
    const fromAddress = from.address;

    // Scan recent blocks.
    for (let i = 0; i < blocksToScan; i++) {
        const blockNumber = currentBlock - i;

        if (blockNumber < 0) break;

        const block = await hardhat.ethers.provider.getBlockWithTransactions(blockNumber);

        // Check all transactions in the block.
        for (const transaction of block.transactions) {
            if (transaction.from === fromAddress && transaction.to === toAddress) {
                // Return the latest transaction found.
                return transaction;
            }
        }
    }

    return null;
};

const getFeeData = async ({ gasPriceIncrementFactorOverride, feeDataLogType = LOG_TYPE.QUIET }) => {
    // Getting and saving fee data to shared state.
    const feeData = await fetchAdjustedFeeData({
        gasPriceIncrementFactorOverride: gasPriceIncrementFactorOverride,
        feeDataLogType: feeDataLogType
    });
    BOOTSTRAP_STATE.feeData = feeData;

    return feeData;
};

module.exports = {
    fetchAdjustedFeeData,
    fetchFeeData,
    fetchGasPrice,
    fetchLatestTransaction,
    getFeeData
};
