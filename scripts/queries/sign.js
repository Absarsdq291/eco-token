const hardhat = require("hardhat");

const sign = async () => {
    // Sign variables.
    let messageDataTypes = process.env.MESSAGE_DATA_TYPES_SIGN;
    let messageData = process.env.MESSAGE_DATA_SIGN;

    // Structuring sign variables.
    messageDataTypes = messageDataTypes.split("|");
    messageData = messageData.split("|");
    messageData.forEach((value, index) => {
        const type = messageDataTypes[index];

        if (type === "bool") {
            messageData[index] = value === "true";
        } else if (type.slice(type.length - 2) === "[]") {
            messageData[index] = value.split("~");
        }
    });

    // Getting wallet.
    const wallet = new hardhat.ethers.Wallet(process.env.PRIVATE_KEY_SIGN);

    // Creating message hash.
    const messageHash = hardhat.ethers.solidityPackedKeccak256(messageDataTypes, messageData);

    // Creating digest.
    const digest = hardhat.ethers.getBytes(messageHash);

    // Creating signature.
    const signature = await wallet.signMessage(digest);

    // Recovering signer.
    const signer = hardhat.ethers.verifyMessage(digest, signature);

    // Splitting signature.
    const r = signature.slice(0, 66);
    const s = "0x" + signature.slice(66, 130);
    const v = "0x" + signature.slice(130, 132);

    // Logging data.
    console.log("v          :", v);
    console.log("r          :", r);
    console.log("s          :", s);
    console.log("Signature  :", signature);
    console.log("Signer     :", signer);

    // Exiting.
    process.exit();
};

sign().catch((error) => {
    // Logging error.
    console.error(error);

    // Exiting with failure.
    process.exitCode = 1;
    process.exit();
});
