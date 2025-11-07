const hardhat = require("hardhat");

const { BLOCKS_STATE, BOOTSTRAP_STATE } = require("../common/states");
const { LOG_TYPE, TX_TYPE } = require("../common/types");
const { waitNextBlock } = require("../utils/blocks");
const { fetchAdjustedFeeData, fetchFeeData, fetchGasPrice } = require("../utils/chain");
const { logNewLine, overwriteLog, separateInitialLogs } = require("../utils/tools");

const initialize = async ({ txTypeOverride, feeDataLogType = LOG_TYPE.VERBOSE } = {}) => {
    // Separating initial logs.
    separateInitialLogs();

    // Getting and saving block time to shared state.
    const blockTime = await loadBlockTime();
    BLOCKS_STATE.blockTime = blockTime;

    // Getting and saving chain id to shared state.
    const chainId = await loadChainId();
    BOOTSTRAP_STATE.chainId = chainId;

    // Logging chain id.
    console.log("Chain Id:", chainId);

    // Getting and saving network to shared state.
    const network = loadNetwork();
    BOOTSTRAP_STATE.network = network;

    // Logging network.
    console.log("Network:", network);

    // Getting and saving tx type to shared state.
    const txType = txTypeOverride || (await loadTxType());
    BOOTSTRAP_STATE.txType = txType;

    // Logging tx type.
    console.log("Tx type:", txType);

    // Getting and saving gas price increment factor to shared state
    const gasPriceIncrementFactor = process.env.GAS_PRICE_INCREMENT_FACTOR || "1";
    BOOTSTRAP_STATE.gasPriceIncrementFactor = gasPriceIncrementFactor;

    // Getting and saving fee data to shared state.
    const feeData = await loadFeeData(feeDataLogType);
    BOOTSTRAP_STATE.feeData = feeData;

    return {
        chainId: chainId,
        network: network,
        txType: txType,
        feeData: feeData
    };
};

const loadBlockTime = async () => {
    // Getting current block number.
    const currentBlockNumber = await hardhat.ethers.provider.getBlockNumber();

    // Retrieving blocks.
    const [currentBlock, previousBlock] = await Promise.all([
        hardhat.ethers.provider.getBlock(currentBlockNumber),
        hardhat.ethers.provider.getBlock(currentBlockNumber - 1)
    ]);

    // Getting block time.
    const blockTime = currentBlock.timestamp - previousBlock.timestamp;

    return blockTime;
};

const loadChainId = async () => {
    // Getting chain id.
    const chainId = Number((await hardhat.ethers.provider.getNetwork()).chainId);

    return chainId;
};

const loadFeeData = async (feeDataLogType) => {
    // Separating logs.
    logNewLine();

    // Getting gas price threshold.
    const gasPriceThreshold = hardhat.ethers.parseUnits(process.env.GAS_PRICE_THRESHOLD || "0", "gwei");

    // Logging gas price threshold.
    const logGasPriceThreshold = Number(hardhat.ethers.formatUnits(gasPriceThreshold, "gwei"));
    console.log("Checking gas price with threshold:", logGasPriceThreshold, "gwei");

    // Flagging whether check needs to be skipped or not.
    const skipGasPriceCheck = !gasPriceThreshold;

    // Getting initial gas price.
    let gasPrice = await fetchGasPrice();

    if (skipGasPriceCheck) {
        console.log("Gas price check skipped");
    } else {
        // Iterating until gas price meets the requirements.
        while (true) {
            // Writing and overwriting gas price.
            const logGasPrice = Number(hardhat.ethers.formatUnits(gasPrice, "gwei")).toFixed(9);
            overwriteLog(`${logGasPrice} gwei`);

            // Conditonally breaking.
            if (gasPrice <= gasPriceThreshold) {
                // Separating logs.
                logNewLine();

                break;
            }

            // Waiting for next block.
            await waitNextBlock();

            // Getting gas price.
            gasPrice = await fetchGasPrice();
        }
    }

    // Logging finalized gas price.
    const logGasPrice = Number(hardhat.ethers.formatUnits(gasPrice, "gwei"));
    console.log("Proceeding with gas price:", logGasPrice, "gwei");

    // Getting incremented fee data.
    const feeData = await fetchAdjustedFeeData({ feeDataLogType: feeDataLogType });

    // Separating logs.
    logNewLine();

    return feeData;
};

const loadNetwork = () => {
    // Getting network.
    const network = hardhat.network.name;

    return network;
};

const loadTxType = async () => {
    // Getting enforced tx type.
    const txTypeEnforced = process.env.TX_TYPE_STATIC;

    // Getting fee data.
    const feeData = await fetchFeeData();

    let txType;

    if (Object.values(TX_TYPE).includes(txTypeEnforced)) {
        if (txTypeEnforced === TX_TYPE.TYPE2) {
            if (feeData.maxFeePerGas) {
                // Will always be type 2.
                txType = txTypeEnforced;
            } else {
                txType = TX_TYPE.TYPE0;
            }
        } else {
            // Will always be type 0.
            txType = txTypeEnforced;
        }
    } else {
        if (feeData.maxFeePerGas) {
            txType = TX_TYPE.TYPE2;
        } else {
            txType = TX_TYPE.TYPE0;
        }
    }

    return txType;
};

module.exports = {
    initialize
};
