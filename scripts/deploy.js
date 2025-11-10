const hardhat = require("hardhat");

const { LOG_TYPE } = require("./config/common/types");
const { initialize } = require("./config/core/bootstrap");
const { deployContract, estimateDeploymentGas, verify } = require("./config/core/operations");
const { getFeeData } = require("./config/utils/chain");
const { updateEnv } = require("./config/utils/env");
const { logNewLine, wait } = require("./config/utils/tools");

const deploy = async () => {
    // Initializing.
    let feeDataLogType = LOG_TYPE.PRIMARY_QUIET;
    const { txType } = await initialize({ feeDataLogType: feeDataLogType });

    // Definition variables.
    const contractName = "Eco";

    // Deployment variables.
    let constructorArguments = [process.env.INITIAL_OWNER,
        process.env.LIQUIDITY_POOL_WALLET,
        process.env.PRESALE_WALLET,
        process.env.MARKETING_WALLET,
        process.env.DEVELOPMENT_WALLET,
        process.env.COMMUNITY_WALLET,
        process.env.VESTED_WALLET];
    let constructorValue = 0;

    // Structuring deployment variables.
    constructorValue = hardhat.ethers.toBigInt(constructorValue || 0);

    // Getting gas limit.
    const gasLimit = await estimateDeploymentGas(contractName, constructorArguments, { value: constructorValue });

    // Logging gas limit.
    const logGasLimit = Number(gasLimit);
    console.log("Gas limit:", logGasLimit);

    // Getting fee data and logging gas price.
    feeDataLogType = LOG_TYPE.SECONDARY_QUIET;
    const feeData = await getFeeData({ feeDataLogType: feeDataLogType });

    // Separating logs.
    logNewLine();

    // Deploying contract.
    const contractAddress = await deployContract(contractName, constructorArguments, {
        type: txType,
        gasLimit: gasLimit,
        ...feeData,
        value: constructorValue
    });

    // Updating env.
    updateEnv("ECO_ADDRESS", contractAddress);

    // Waiting for block explorer.
    await wait("60 seconds");

    // Verifying contract.
    await verify(contractAddress, constructorArguments);

    // Exiting.
    process.exit();
};

deploy().catch((error) => {
    // Logging error.
    console.error(error);

    // Exiting with failure.
    process.exitCode = 1;
    process.exit();
});
