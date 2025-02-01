;; EcoVault - Round up savings for eco initiatives

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-no-rewards (err u104))
(define-constant withdrawal-lock-period u144) ;; ~24 hours in blocks
(define-constant rewards-threshold u1000) ;; Minimum funding to earn rewards
(define-constant rewards-percentage u5) ;; 5% rewards

;; Data vars
(define-map user-vaults principal {
    balance: uint,
    last-deposit: uint,
    last-withdrawal: uint,
    rewards-earned: uint
})

(define-map initiatives uint {
    name: (string-ascii 64),
    verified: bool,
    total-funding: uint,
    contributors: uint
})

(define-data-var initiative-counter uint u0)
(define-data-var total-rewards-distributed uint u0)

;; Private functions
(define-private (get-vault-or-default (user principal))
    (default-to
        {
            balance: u0,
            last-deposit: u0,
            last-withdrawal: u0,
            rewards-earned: u0
        }
        (map-get? user-vaults user)
    )
)

(define-private (calculate-rewards (amount uint))
    (/ (* amount rewards-percentage) u100)
)

;; Public functions
(define-public (deposit (amount uint))
    (let (
        (current-vault (get-vault-or-default tx-sender))
        (new-balance (+ (get balance current-vault) amount))
    )
    (if (> amount u0)
        (begin
            (map-set user-vaults tx-sender {
                balance: new-balance,
                last-deposit: block-height,
                last-withdrawal: (get last-withdrawal current-vault),
                rewards-earned: (get rewards-earned current-vault)
            })
            (ok true))
        err-invalid-amount
    ))
)

(define-public (withdraw (amount uint))
    (let (
        (current-vault (get-vault-or-default tx-sender))
        (current-balance (get balance current-vault))
        (last-withdrawal-height (get last-withdrawal current-vault))
    )
    (asserts! (>= current-balance amount) err-insufficient-balance)
    (asserts! (>= block-height (+ last-withdrawal-height withdrawal-lock-period)) err-unauthorized)
    (map-set user-vaults tx-sender {
        balance: (- current-balance amount),
        last-deposit: (get last-deposit current-vault),
        last-withdrawal: block-height,
        rewards-earned: (get rewards-earned current-vault)
    })
    (ok true))
)

(define-public (register-initiative (name (string-ascii 64)))
    (let (
        (counter (var-get initiative-counter))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set initiatives counter {
        name: name,
        verified: false,
        total-funding: u0,
        contributors: u0
    })
    (var-set initiative-counter (+ counter u1))
    (ok counter))
)

(define-public (verify-initiative (initiative-id uint))
    (let (
        (initiative (unwrap! (map-get? initiatives initiative-id) err-invalid-amount))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set initiatives initiative-id {
        name: (get name initiative),
        verified: true,
        total-funding: (get total-funding initiative),
        contributors: (get contributors initiative)
    })
    (ok true))
)

(define-public (fund-initiative (initiative-id uint) (amount uint))
    (let (
        (current-vault (get-vault-or-default tx-sender))
        (initiative (unwrap! (map-get? initiatives initiative-id) err-invalid-amount))
        (rewards (if (>= amount rewards-threshold) 
                   (calculate-rewards amount)
                   u0))
    )
    (asserts! (>= (get balance current-vault) amount) err-insufficient-balance)
    (asserts! (get verified initiative) err-unauthorized)
    
    ;; Update user vault
    (map-set user-vaults tx-sender {
        balance: (- (get balance current-vault) amount),
        last-deposit: (get last-deposit current-vault),
        last-withdrawal: (get last-withdrawal current-vault),
        rewards-earned: (+ (get rewards-earned current-vault) rewards)
    })
    
    ;; Update initiative funding
    (map-set initiatives initiative-id {
        name: (get name initiative),
        verified: true,
        total-funding: (+ (get total-funding initiative) amount),
        contributors: (+ (get contributors initiative) u1)
    })

    ;; Update total rewards
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
    (ok rewards))
)

;; Read only functions
(define-read-only (get-vault-balance (user principal))
    (get balance (get-vault-or-default user))
)

(define-read-only (get-vault-rewards (user principal))
    (get rewards-earned (get-vault-or-default user))
)

(define-read-only (get-initiative-details (initiative-id uint))
    (map-get? initiatives initiative-id)
)

(define-read-only (get-total-rewards-distributed)
    (var-get total-rewards-distributed)
)
