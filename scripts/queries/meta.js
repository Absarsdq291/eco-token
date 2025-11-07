const hardhat = require("hardhat");

const meta = () => {
    // Meta variables.
    let messageDataTypes = process.env.MESSAGE_DATA_TYPES_META;
    let messageData = process.env.MESSAGE_DATA_META;
    const messageDataTypehash = process.env.MESSAGE_DATA_TYPEHASH_META;
    const domainSeparator = process.env.DOMAIN_SEPARATOR_META;

    // Structuring meta variables.
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
    messageDataTypes.unshift("bytes32");
    messageData.unshift(messageDataTypehash);

    // Getting wallet.
    const wallet = new hardhat.ethers.Wallet(process.env.PRIVATE_KEY_META);

    // Creating message hash.
    const messageHash = hardhat.ethers.keccak256(
        hardhat.ethers.AbiCoder.defaultAbiCoder().encode(messageDataTypes, messageData)
    );

    // Creating digest.
    const digest = hardhat.ethers.keccak256(hardhat.ethers.concat(["0x1901", domainSeparator, messageHash]));

    // Creating signature.
    const signature = wallet.signingKey.sign(digest).serialized;

    // Recovering signer.
    const signer = hardhat.ethers.recoverAddress(digest, signature);

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

meta().catch((error) => {
    // Logging error.
    console.error(error);

    // Exiting with failure.
    process.exitCode = 1;
    process.exit();
});
