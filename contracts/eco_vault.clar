;; EcoVault - Round up savings for eco initiatives

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-no-rewards (err u104))
(define-constant err-paused (err u105))
(define-constant err-deposit-limit (err u106))
(define-constant withdrawal-lock-period u144) ;; ~24 hours in blocks
(define-constant rewards-threshold u1000) ;; Minimum funding to earn rewards
(define-constant rewards-percentage u5) ;; 5% rewards
(define-constant max-deposit u1000000000) ;; Maximum deposit limit

;; Data vars
(define-data-var contract-paused bool false)
(define-data-var total-deposits uint u0)

(define-map user-vaults principal {
    balance: uint,
    last-deposit: uint,
    last-withdrawal: uint,
    rewards-earned: uint,
    total-contributed: uint
})

(define-map initiatives uint {
    name: (string-ascii 64),
    verified: bool,
    total-funding: uint,
    contributors: uint,
    status: (string-ascii 16),
    created-at: uint
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
            rewards-earned: u0,
            total-contributed: u0
        }
        (map-get? user-vaults user)
    )
)

(define-private (calculate-rewards (amount uint))
    (/ (* amount rewards-percentage) u100)
)

;; Admin functions
(define-public (set-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused paused)
        (print {event: "contract-pause-updated", paused: paused})
        (ok true))
)

;; Public functions
(define-public (deposit (amount uint))
    (let (
        (current-vault (get-vault-or-default tx-sender))
        (new-balance (+ (get balance current-vault) amount))
        (new-total-deposits (+ (var-get total-deposits) amount))
    )
    (asserts! (not (var-get contract-paused)) err-paused)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount max-deposit) err-deposit-limit)
    
    (map-set user-vaults tx-sender {
        balance: new-balance,
        last-deposit: block-height,
        last-withdrawal: (get last-withdrawal current-vault),
        rewards-earned: (get rewards-earned current-vault),
        total-contributed: (get total-contributed current-vault)
    })
    (var-set total-deposits new-total-deposits)
    (print {event: "deposit", user: tx-sender, amount: amount})
    (ok true))
)

;; [Previous functions remain unchanged...]

;; New getter functions
(define-read-only (get-contract-status)
    (var-get contract-paused)
)

(define-read-only (get-total-deposits)
    (var-get total-deposits)
)

(define-read-only (get-user-stats (user principal))
    (get-vault-or-default user)
)
