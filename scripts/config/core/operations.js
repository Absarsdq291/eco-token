/**
 * @type {import("hardhat/types").HardhatRuntimeEnvironment & import("@openzeppelin/hardhat-upgrades").HardhatUpgrades}
 */
const hardhat = require("hardhat");

const { waitNextBlock } = require("../utils/blocks");
const { logNewLine } = require("../utils/tools");

const deployContract = async (contractName, constructorArguments, contractOptions) => {
    // Deploying proxy.
    const contract = await hardhat.ethers.deployContract(contractName, constructorArguments, contractOptions);
    await contract.waitForDeployment();

    // Getting contract deployment variables.
    const contractAddress = contract.target;
    const deploymentTransactionHash = contract.deploymentTransaction().hash;
    const deploymentTransaction = await hardhat.ethers.provider.getTransactionReceipt(deploymentTransactionHash);
    const deploymentBlockNumber = deploymentTransaction.blockNumber;

    // Logging contract deployment variables.
    console.log(contractName, "deployed to:", contractAddress);
    console.log("at block number:", deploymentBlockNumber);

    return contractAddress;
};

const deployProxy = async (contractName, initializerArguments, contractOptions, proxyOptions) => {
    // Getting contract factory.
    const contractFactory = await hardhat.ethers.getContractFactory(contractName, contractOptions);

    // Deploying proxy.
    const proxy = await hardhat.upgrades.deployProxy(contractFactory, initializerArguments, proxyOptions);
    await proxy.waitForDeployment();

    // Getting proxy deployment variables.
    const proxyAddress = proxy.target;
    const deploymentTransactionHash = proxy.deploymentTransaction().hash;
    const deploymentTransaction = await hardhat.ethers.provider.getTransactionReceipt(deploymentTransactionHash);
    const deploymentBlockNumber = deploymentTransaction.blockNumber;
    const proxyAdminAddress = await hardhat.upgrades.erc1967.getAdminAddress(proxyAddress);
    const implementationAddress = await hardhat.upgrades.erc1967.getImplementationAddress(proxyAddress);

    // Logging proxy deployment variables.
    console.log(contractName, "proxy deployed to:", proxyAddress);
    console.log("at block number:", deploymentBlockNumber);
    console.log(contractName, "proxy admin:", proxyAdminAddress);
    console.log(contractName, "implementation:", implementationAddress);

    return {
        proxyAddress: proxyAddress,
        proxyAdminAddress: proxyAdminAddress,
        implementationAddress: implementationAddress
    };
};

const estimateDeploymentGas = async (contractName, constructorArguments, contractOptions) => {
    // Getting contract artifact.
    const contractArtifact = await hardhat.artifacts.readArtifact(contractName);

    // Getting contract interface and bytecode.
    const contractInterface = new hardhat.ethers.Interface(contractArtifact.abi);
    const bytecode = contractArtifact.bytecode;

    // Getting encoded constructor arguments.
    const encodedArgs = contractInterface.encodeDeploy(constructorArguments);

    // Getting contract deployment data.
    const deploymentData = bytecode + encodedArgs.slice(2);

    // Getting gas limit.
    const gasLimit = await hardhat.ethers.provider.estimateGas({ data: deploymentData, ...contractOptions });

    return gasLimit;
};

const upgradeProxy = async (contractName, proxyAddress, contractOptions, upgradeOptions) => {
    // Getting old implementation address.
    const oldImplementationAddress = await hardhat.upgrades.erc1967.getImplementationAddress(proxyAddress);

    // Getting contract factory.
    const contractFactory = await hardhat.ethers.getContractFactory(contractName, contractOptions);

    // Upgrading proxy.
    await hardhat.upgrades.upgradeProxy(proxyAddress, contractFactory, upgradeOptions);

    // Getting proxy upgrade variables.
    let implementationAddress;

    do {
        // Waiting for next block.
        await waitNextBlock();

        // Getting implementation address.
        implementationAddress = await hardhat.upgrades.erc1967.getImplementationAddress(proxyAddress);
    } while (implementationAddress === oldImplementationAddress);

    // Logging proxy upgrade variables.
    console.log(contractName, "proxy upgraded at:", proxyAddress);
    console.log(contractName, "implementation:", implementationAddress);

    return implementationAddress;
};

const verify = async (contractAddress, constructorArguments, contractPath) => {
    // Separating logs.
    logNewLine();

    // Logging contract verification variables.
    console.log("Verifying contract at:", contractAddress);
    console.log("with arguments:", constructorArguments);
    if (contractPath) console.log("at path:", contractPath);

    // Separating logs.
    logNewLine();

    // Verifying contract.
    await hardhat.run("verify:verify", {
        address: contractAddress,
        constructorArguments: constructorArguments,
        contract: contractPath
    });
};

module.exports = {
    deployContract,
    deployProxy,
    estimateDeploymentGas,
    upgradeProxy,
    verify
};
