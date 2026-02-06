use anchor_lang::prelude::*;
use anchor_spl::token_2022::{self, Token2022, TransferChecked};
use anchor_spl::token_interface::{Mint, TokenAccount};

declare_id!("TRZAFeeSp1itterProgram111111111111111111111");

/// Treza Fee Splitter Program
/// 
/// This program manages the 50/50 split of collected transfer fees
/// from the Treza Token-2022 token to two treasury wallets.
/// 
/// Flow:
/// 1. Token-2022 withholds 5% fees in recipient accounts
/// 2. Authority harvests fees to a collection account
/// 3. This program splits collected fees 50/50 to treasuries
#[program]
pub mod treza_fee_splitter {
    use super::*;

    /// Initialize the fee splitter configuration
    /// 
    /// Creates a config PDA storing treasury wallet addresses and authority
    pub fn initialize(
        ctx: Context<Initialize>,
        treasury_wallet_1: Pubkey,
        treasury_wallet_2: Pubkey,
    ) -> Result<()> {
        require!(
            treasury_wallet_1 != treasury_wallet_2,
            TrezaError::DuplicateTreasuryWallets
        );
        require!(
            treasury_wallet_1 != Pubkey::default(),
            TrezaError::InvalidTreasuryWallet
        );
        require!(
            treasury_wallet_2 != Pubkey::default(),
            TrezaError::InvalidTreasuryWallet
        );

        let config = &mut ctx.accounts.config;
        config.authority = ctx.accounts.authority.key();
        config.treasury_wallet_1 = treasury_wallet_1;
        config.treasury_wallet_2 = treasury_wallet_2;
        config.mint = ctx.accounts.mint.key();
        config.total_fees_distributed = 0;
        config.bump = ctx.bumps.config;

        emit!(ConfigInitialized {
            authority: config.authority,
            treasury_wallet_1,
            treasury_wallet_2,
            mint: config.mint,
        });

        Ok(())
    }

    /// Split fees from collection account to two treasury wallets
    /// 
    /// Takes all tokens from the fee collection account and splits 50/50
    /// Handles odd amounts by giving remainder to treasury_wallet_2
    pub fn split_fees(ctx: Context<SplitFees>) -> Result<()> {
        let collection_balance = ctx.accounts.fee_collection_account.amount;
        
        require!(
            collection_balance > 0,
            TrezaError::NoFeesToSplit
        );

        // Calculate 50/50 split (wallet_2 gets remainder for odd amounts)
        let amount_to_wallet_1 = collection_balance / 2;
        let amount_to_wallet_2 = collection_balance - amount_to_wallet_1;

        let mint_key = ctx.accounts.config.mint;
        let seeds = &[
            b"config",
            mint_key.as_ref(),
            &[ctx.accounts.config.bump],
        ];
        let signer_seeds = &[&seeds[..]];

        // Transfer to treasury wallet 1
        if amount_to_wallet_1 > 0 {
            let cpi_accounts_1 = TransferChecked {
                from: ctx.accounts.fee_collection_account.to_account_info(),
                mint: ctx.accounts.mint.to_account_info(),
                to: ctx.accounts.treasury_account_1.to_account_info(),
                authority: ctx.accounts.config.to_account_info(),
            };
            let cpi_ctx_1 = CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                cpi_accounts_1,
                signer_seeds,
            );
            token_2022::transfer_checked(
                cpi_ctx_1,
                amount_to_wallet_1,
                ctx.accounts.mint.decimals,
            )?;
        }

        // Transfer to treasury wallet 2
        if amount_to_wallet_2 > 0 {
            let cpi_accounts_2 = TransferChecked {
                from: ctx.accounts.fee_collection_account.to_account_info(),
                mint: ctx.accounts.mint.to_account_info(),
                to: ctx.accounts.treasury_account_2.to_account_info(),
                authority: ctx.accounts.config.to_account_info(),
            };
            let cpi_ctx_2 = CpiContext::new_with_signer(
                ctx.accounts.token_program.to_account_info(),
                cpi_accounts_2,
                signer_seeds,
            );
            token_2022::transfer_checked(
                cpi_ctx_2,
                amount_to_wallet_2,
                ctx.accounts.mint.decimals,
            )?;
        }

        // Update stats
        let config = &mut ctx.accounts.config;
        config.total_fees_distributed = config
            .total_fees_distributed
            .checked_add(collection_balance)
            .ok_or(TrezaError::Overflow)?;

        emit!(FeesSplit {
            amount_to_wallet_1,
            amount_to_wallet_2,
            total_distributed: config.total_fees_distributed,
        });

        Ok(())
    }

    /// Update treasury wallet addresses
    /// 
    /// Only callable by the current authority
    pub fn update_treasury_wallets(
        ctx: Context<UpdateConfig>,
        new_treasury_wallet_1: Pubkey,
        new_treasury_wallet_2: Pubkey,
    ) -> Result<()> {
        require!(
            new_treasury_wallet_1 != new_treasury_wallet_2,
            TrezaError::DuplicateTreasuryWallets
        );
        require!(
            new_treasury_wallet_1 != Pubkey::default(),
            TrezaError::InvalidTreasuryWallet
        );
        require!(
            new_treasury_wallet_2 != Pubkey::default(),
            TrezaError::InvalidTreasuryWallet
        );

        let config = &mut ctx.accounts.config;
        let old_wallet_1 = config.treasury_wallet_1;
        let old_wallet_2 = config.treasury_wallet_2;

        config.treasury_wallet_1 = new_treasury_wallet_1;
        config.treasury_wallet_2 = new_treasury_wallet_2;

        emit!(TreasuryWalletsUpdated {
            old_wallet_1,
            old_wallet_2,
            new_wallet_1: new_treasury_wallet_1,
            new_wallet_2: new_treasury_wallet_2,
        });

        Ok(())
    }

    /// Transfer authority to a new address
    /// 
    /// Only callable by the current authority
    pub fn transfer_authority(
        ctx: Context<UpdateConfig>,
        new_authority: Pubkey,
    ) -> Result<()> {
        require!(
            new_authority != Pubkey::default(),
            TrezaError::InvalidAuthority
        );

        let config = &mut ctx.accounts.config;
        let old_authority = config.authority;
        config.authority = new_authority;

        emit!(AuthorityTransferred {
            old_authority,
            new_authority,
        });

        Ok(())
    }
}

// ============================================================================
// ACCOUNTS
// ============================================================================

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + FeeConfig::INIT_SPACE,
        seeds = [b"config", mint.key().as_ref()],
        bump
    )]
    pub config: Account<'info, FeeConfig>,

    /// The Token-2022 mint for TREZA
    pub mint: InterfaceAccount<'info, Mint>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct SplitFees<'info> {
    /// Anyone can call split_fees (permissionless cranking)
    pub payer: Signer<'info>,

    #[account(
        mut,
        seeds = [b"config", config.mint.as_ref()],
        bump = config.bump,
    )]
    pub config: Account<'info, FeeConfig>,

    /// The Token-2022 mint
    #[account(
        constraint = mint.key() == config.mint @ TrezaError::InvalidMint
    )]
    pub mint: InterfaceAccount<'info, Mint>,

    /// Fee collection account (owned by config PDA)
    #[account(
        mut,
        token::mint = mint,
        token::authority = config,
        token::token_program = token_program,
    )]
    pub fee_collection_account: InterfaceAccount<'info, TokenAccount>,

    /// Treasury wallet 1 token account
    #[account(
        mut,
        token::mint = mint,
        token::token_program = token_program,
        constraint = treasury_account_1.owner == config.treasury_wallet_1 @ TrezaError::InvalidTreasuryAccount
    )]
    pub treasury_account_1: InterfaceAccount<'info, TokenAccount>,

    /// Treasury wallet 2 token account
    #[account(
        mut,
        token::mint = mint,
        token::token_program = token_program,
        constraint = treasury_account_2.owner == config.treasury_wallet_2 @ TrezaError::InvalidTreasuryAccount
    )]
    pub treasury_account_2: InterfaceAccount<'info, TokenAccount>,

    pub token_program: Program<'info, Token2022>,
}

#[derive(Accounts)]
pub struct UpdateConfig<'info> {
    #[account(
        constraint = authority.key() == config.authority @ TrezaError::Unauthorized
    )]
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [b"config", config.mint.as_ref()],
        bump = config.bump,
    )]
    pub config: Account<'info, FeeConfig>,
}

// ============================================================================
// STATE
// ============================================================================

#[account]
#[derive(InitSpace)]
pub struct FeeConfig {
    /// Authority that can update config
    pub authority: Pubkey,
    /// First treasury wallet (receives 50% of fees)
    pub treasury_wallet_1: Pubkey,
    /// Second treasury wallet (receives 50% of fees)
    pub treasury_wallet_2: Pubkey,
    /// The Token-2022 mint address
    pub mint: Pubkey,
    /// Total fees distributed through this program
    pub total_fees_distributed: u64,
    /// PDA bump seed
    pub bump: u8,
}

// ============================================================================
// EVENTS
// ============================================================================

#[event]
pub struct ConfigInitialized {
    pub authority: Pubkey,
    pub treasury_wallet_1: Pubkey,
    pub treasury_wallet_2: Pubkey,
    pub mint: Pubkey,
}

#[event]
pub struct FeesSplit {
    pub amount_to_wallet_1: u64,
    pub amount_to_wallet_2: u64,
    pub total_distributed: u64,
}

#[event]
pub struct TreasuryWalletsUpdated {
    pub old_wallet_1: Pubkey,
    pub old_wallet_2: Pubkey,
    pub new_wallet_1: Pubkey,
    pub new_wallet_2: Pubkey,
}

#[event]
pub struct AuthorityTransferred {
    pub old_authority: Pubkey,
    pub new_authority: Pubkey,
}

// ============================================================================
// ERRORS
// ============================================================================

#[error_code]
pub enum TrezaError {
    #[msg("Treasury wallets must be different addresses")]
    DuplicateTreasuryWallets,

    #[msg("Invalid treasury wallet address")]
    InvalidTreasuryWallet,

    #[msg("Invalid authority address")]
    InvalidAuthority,

    #[msg("No fees available to split")]
    NoFeesToSplit,

    #[msg("Invalid mint address")]
    InvalidMint,

    #[msg("Invalid treasury token account")]
    InvalidTreasuryAccount,

    #[msg("Unauthorized - only authority can perform this action")]
    Unauthorized,

    #[msg("Arithmetic overflow")]
    Overflow,
}
