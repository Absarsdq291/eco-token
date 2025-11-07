const hardhat = require("hardhat");

const resolve = () => {
    // Resolve variables.
    const privateKey = process.env.PRIVATE_KEY_RESOLVE;

    // Getting wallet.
    const wallet = new hardhat.ethers.Wallet(privateKey);

    // Logging data.
    console.log("Address:", wallet.address);

    // Exiting.
    process.exit();
};

resolve().catch((error) => {
    // Logging error.
    console.error(error);

    // Exiting with failure.
    process.exitCode = 1;
    process.exit();
});
