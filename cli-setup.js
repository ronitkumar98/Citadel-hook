import { ethers } from 'ethers';
import chalk from 'chalk';
import { select, confirm, input } from '@inquirer/prompts';
import dotenv from 'dotenv';

dotenv.config();

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);

// Wallets
const adminWallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const unverifiedWallet = new ethers.Wallet(process.env.UNVERIFIED_PRIVATE_KEY, provider);
const verifiedWallet = new ethers.Wallet(process.env.VERIFIED_PRIVATE_KEY, provider);

// Constants from your deployment
const ASSET_REGISTRY_ADDRESS = "0x181aEcDc321e582340982AC53BA62Cee16CeeF56"; 
const IDENTITY_REGISTRY_ADDRESS = "0x2FC8b7064453792D3EEF982dA01FFa9f6ea18cA8";
const HOOK_ADDRESS = "0xd82eF7E7CF1B96daDD0703b47274835a996f4880";
const USDT_ADDRESS = "0x598C00BA505De7c9f5059e163570c9059CFcD19F";
const POOL_SWAP_TEST_ADDRESS = "0x74fec58f4d0166Ea276e13c20cA847e1f6c99f0c"; // e.g., standard Sepolia v4 test router

// ABIs
const assetRegistryAbi = [
    "function setStatus(address token, uint8 status)", 
    "function getStatus(address token) view returns (uint8)"
];
const identityRegistryAbi = [
    "function registerUser(address user)", 
    "function isVerified(address user) view returns (bool)"
];
const poolSwapTestAbi = [
    // V4 SwapRouter/PoolSwapTest standard testnet interface
    "function swap((address,address,uint24,int24,address) key, (bool,int256,uint160) params, (bool,bool) testSettings, bytes hookData) payable returns (int256 delta)"
];
const erc20Abi = [
    "function balanceOf(address owner) view returns (uint256)",
    "function decimals() view returns (uint8)"
];

// Contract Instances
const assetRegistry = new ethers.Contract(ASSET_REGISTRY_ADDRESS, assetRegistryAbi, adminWallet);
const identityRegistry = new ethers.Contract(IDENTITY_REGISTRY_ADDRESS, identityRegistryAbi, adminWallet);

// Pool Key Configuration (Matches your CreatePool.s.sol)
const poolKey = [
    ethers.ZeroAddress, // Native ETH (currency0)
    USDT_ADDRESS,       // USDT (currency1)
    4000,               // Fee
    60,                 // TickSpacing
    HOOK_ADDRESS        // Your Citadel Hook
];

// Helper for UI pauses
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function executeSwap(wallet, sceneName) {
    const swapRouter = new ethers.Contract(POOL_SWAP_TEST_ADDRESS, poolSwapTestAbi, wallet);
    
    // V4 FIX: Negative amountSpecified for EXACT INPUT
    const exactInputAmount = ethers.parseEther("-0.001"); 
    
    const swapParams = [
        true, // zeroForOne (Selling ETH for USDT)
        exactInputAmount, 
        "4295128740" // MIN_SQRT_PRICE + 1 (Must be strictly > MIN_SQRT_PRICE)
    ];
    
    const testSettings = [false, false]; // takeClaims, settleUsingBurn
    
    console.log(chalk.gray(`\n  [Network] Initiating swap on Sepolia...`));
    console.log(chalk.gray(`  [Network] From: ${wallet.address}`));
    
    try {
        const tx = await swapRouter.swap(
            poolKey, 
            swapParams, 
            testSettings, 
            "0x", // empty hookData
            { value: ethers.parseEther("0.001") } // msg.value must be positive
        );
        console.log(chalk.yellow(`  [Network] Tx broadcasted! Hash: ${tx.hash}`));
        console.log(chalk.yellow(`  [Network] Waiting for confirmation...`));
        
        await tx.wait();
        return { success: true, message: "Swap executed successfully!" };
    } catch (error) {
        // Advanced Error Catching for V4 Custom Errors
        const rawErrorHex = error.data || (error.info && error.info.error && error.info.error.data) || null;
        let errorMsg = error.shortMessage || error.message;

        if (errorMsg.includes("User Not KYC'd")) {
            errorMsg = "Citadel: User Not KYC'd";
        } else if (errorMsg.includes("Asset Frozen/Litigation")) {
            errorMsg = "Citadel: Asset Frozen/Litigation";
        } else if (rawErrorHex) {
            errorMsg = `Uniswap V4 Custom Error Revert Hex: ${rawErrorHex}`;
        }

        return { success: false, message: errorMsg };
    }
}

async function runDemo() {
    console.clear();
    console.log(chalk.bgBlue.white.bold("\n === THE CITADEL: RWA COMPLIANCE ENGINE === \n"));
    console.log(chalk.gray("Connected to Sepolia Testnet. Wallets loaded.\n"));

    while (true) {
        const action = await select({
            message: 'Select a demo scene to execute:',
            choices: [
                { name: '[ Scene 1 ] Verify Current Asset Status (Circuit Breaker)', value: 'scene1' },
                { name: '[ Scene 2 ] The Compliance Block (Unverified User Swap)', value: 'scene2' },
                { name: '[ Scene 3 ] The Happy Path (Verify User & Swap)', value: 'scene3' },
                { name: '[ Scene 4 ] Execute Emergency Injunction (Admin Freeze)', value: 'scene4' },
                { name: '[ Scene 5 ] The Protection (Verified User on Frozen Asset)', value: 'scene5' },
                { name: '[ Utility ] User Management: Check & Register Identity', value: 'manage_user' },
                { name: '[ Utility ] Wallet Balances: Check ETH and USDT', value: 'check_balance' },
                { name: '[ Reset   ] Reset Demo: Unfreeze Asset', value: 'reset' },
                { name: 'Exit', value: 'exit' }
            ]
        });

        if (action === 'exit') {
            console.log(chalk.green("Exiting Citadel Terminal. Goodbye."));
            process.exit(0);
        }

        try {
            switch (action) {
                case 'scene1':
                    console.log(chalk.cyan("\n[Scene 1] Querying AssetStatusRegistry on Sepolia..."));
                    await sleep(800);
                    const status0 = await assetRegistry.getStatus(ethers.ZeroAddress);
                    const status1 = await assetRegistry.getStatus(USDT_ADDRESS);
                    
                    if (status0 === 0n && status1 === 0n) {
                        console.log(chalk.green("[SUCCESS] Asset Status is GREEN (ACTIVE). Legally safe to trade."));
                    } else {
                        console.log(chalk.yellow(`[WARNING] Asset Status is currently ${status1} (Not Active).`));
                    }
                    break;

                case 'scene2':
                    console.log(chalk.cyan("\n[Scene 2] Simulating malicious/unverified actor..."));
                    await sleep(1000);
                    console.log(chalk.magenta("  Attempting to execute swap through PoolManager..."));
                    
                    const res2 = await executeSwap(unverifiedWallet, "Scene 2");
                    if (!res2.success) {
                        console.log(chalk.red.bold(`\n[BLOCKED] Transaction Blocked by Hook!\n  Reason: ${res2.message}`));
                    } else {
                        console.log(chalk.red("[FAIL] Wait, this should have failed! Check hook deployment."));
                    }
                    break;

                case 'scene3':
                    console.log(chalk.cyan("\n[Scene 3] Registering Institutional Client via ERC-3643 Mock..."));
                    const checkVerified = await identityRegistry.isVerified(verifiedWallet.address);
                    
                    if (!checkVerified) {
                        console.log(chalk.yellow(`  [Network] Whitelisting wallet... `));
                        const txVerify = await identityRegistry.registerUser(verifiedWallet.address);
                        console.log(chalk.yellow(`  [Network] Hash: ${txVerify.hash}`));
                        await txVerify.wait();
                        console.log(chalk.green("[SUCCESS] Wallet Identity Verified."));
                    } else {
                        console.log(chalk.green("[SUCCESS] Wallet already Verified in Registry."));
                    }

                    await sleep(1000);
                    console.log(chalk.cyan("\nExecuting compliant swap..."));
                    
                    const res3 = await executeSwap(verifiedWallet, "Scene 3");
                    if (res3.success) {
                        console.log(chalk.green.bold(`\n[SUCCESS] Swap Successful! Assets settled natively via V4.`));
                    } else {
                        console.log(chalk.red(`[FAIL] Swap failed: ${res3.message}`));
                    }
                    break;

                case 'scene4':
                    console.log(chalk.bgRed.white.bold("\n [CRITICAL ALERT] LEGAL INJUNCTION RECEIVED ON ASSET "));
                    const proceed = await confirm({ message: 'Execute emergency circuit breaker on USDT pair?' });
                    if (proceed) {
                        console.log(chalk.yellow("  [Network] Broadcasting setStatus(FROZEN)..."));
                        const txFreeze = await assetRegistry.setStatus(USDT_ADDRESS, 1); // 1 = FROZEN
                        await txFreeze.wait();
                        console.log(chalk.red.bold("[LOCKED] ASSET FROZEN. The Citadel Hook has locked the pool globally."));
                    }
                    break;

                case 'scene5':
                    console.log(chalk.cyan("\n[Scene 5] Verified Client attempting to swap frozen asset..."));
                    await sleep(1000);
                    
                    const res5 = await executeSwap(verifiedWallet, "Scene 5");
                    if (!res5.success) {
                        console.log(chalk.red.bold(`\n[BLOCKED] Transaction Blocked by Hook!\n  Reason: ${res5.message}`));
                    } else {
                        console.log(chalk.red("[WARNING] Swap succeeded on a frozen asset."));
                    }
                    break;
                
                case 'manage_user':
                    console.log(chalk.cyan("\n[User Management] Query or Update Identity Registry"));
                    
                    const addressToCheck = await input({ message: 'Enter the Ethereum address to check:' });
                    
                    if (!ethers.isAddress(addressToCheck)) {
                        console.log(chalk.red("[ERROR] Invalid Ethereum address."));
                        break;
                    }

                    console.log(chalk.gray(`\n  Checking Identity Registry for ${addressToCheck}...`));
                    const isReg = await identityRegistry.isVerified(addressToCheck);

                    if (isReg) {
                        console.log(chalk.green(`[VERIFIED] Status: User ${addressToCheck} is already VERIFIED.`));
                    } else {
                        console.log(chalk.yellow(`[UNVERIFIED] Status: User ${addressToCheck} is NOT VERIFIED.`));
                        
                        const doRegister = await confirm({ message: 'Would you like to register this user now?' });
                        if (doRegister) {
                            console.log(chalk.yellow("\n  [Network] Broadcasting registerUser transaction..."));
                            const txReg = await identityRegistry.registerUser(addressToCheck);
                            console.log(chalk.yellow(`  [Network] Hash: ${txReg.hash}`));
                            console.log(chalk.yellow(`  [Network] Waiting for confirmation...`));
                            await txReg.wait();
                            console.log(chalk.green(`[SUCCESS] User ${addressToCheck} is now permanently verified.`));
                        } else {
                            console.log(chalk.gray("Registration cancelled by admin."));
                        }
                    }
                    break;

                case 'check_balance':
                    console.log(chalk.cyan("\n[Wallet Balances] Query ETH and USDT"));
                    const addressToQuery = await input({ message: 'Enter the Ethereum address to check (leave blank for verified user):' });
                    const targetAddress = addressToQuery.trim() === "" ? verifiedWallet.address : addressToQuery;

                    if (!ethers.isAddress(targetAddress)) {
                        console.log(chalk.red("[ERROR] Invalid Ethereum address."));
                        break;
                    }

                    console.log(chalk.gray(`\n  Fetching balances for ${targetAddress}...`));
                    
                    const ethBalance = await provider.getBalance(targetAddress);
                    
                    const usdtContract = new ethers.Contract(USDT_ADDRESS, erc20Abi, provider);
                    const usdtBalance = await usdtContract.balanceOf(targetAddress);
                    const usdtDecimals = await usdtContract.decimals();

                    console.log(chalk.green(`  ETH Balance:  ${ethers.formatEther(ethBalance)} ETH`));
                    console.log(chalk.green(`  USDT Balance: ${ethers.formatUnits(usdtBalance, usdtDecimals)} USDT`));
                    break;

                case 'reset':
                    console.log(chalk.cyan("\nResetting asset status to ACTIVE..."));
                    const txReset = await assetRegistry.setStatus(USDT_ADDRESS, 0); // 0 = ACTIVE
                    await txReset.wait();
                    console.log(chalk.green("[SUCCESS] Asset unfrozen. Demo reset."));
                    break;
            }
        } catch (error) {
            console.log(chalk.red(`\n[ERROR] Unexpected Error: ${error.message}`));
        }
        
        console.log("\n" + chalk.gray("─".repeat(70)) + "\n");
        await input({ message: "Press Enter to continue..." });
    }
}

runDemo();