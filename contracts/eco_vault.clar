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
(define-constant err-cooldown-active (err u107))
(define-constant err-rate-limit (err u108))

(define-constant withdrawal-lock-period u144) ;; ~24 hours in blocks
(define-constant rewards-threshold u1000) ;; Minimum funding to earn rewards
(define-constant rewards-percentage u5) ;; 5% rewards
(define-constant max-deposit u1000000000) ;; Maximum deposit limit
(define-constant rate-limit-window u144) ;; 24-hour window for rate limiting
(define-constant max-deposits-per-window u10) ;; Max deposits per window

;; Data vars
(define-data-var contract-paused bool false)
(define-data-var total-deposits uint u0)

;; Enhanced user vault mapping
(define-map user-vaults principal {
    balance: uint,
    last-deposit: uint,
    last-withdrawal: uint,
    rewards-earned: uint,
    total-contributed: uint,
    deposits-in-window: uint,
    window-start: uint,
    deposit-history: (list 10 uint)
})

;; [Previous initiative mapping remains unchanged...]

;; Private functions
(define-private (get-vault-or-default (user principal))
    (default-to
        {
            balance: u0,
            last-deposit: u0,
            last-withdrawal: u0,
            rewards-earned: u0,
            total-contributed: u0,
            deposits-in-window: u0,
            window-start: u0,
            deposit-history: (list)
        }
        (map-get? user-vaults user)
    )
)

(define-private (update-rate-limit (vault-data (tuple (deposits-in-window uint) (window-start uint))))
    (if (> (- block-height (get window-start vault-data)) rate-limit-window)
        ;; Reset window if expired
        {
            deposits-in-window: u1,
            window-start: block-height
        }
        ;; Increment within current window
        {
            deposits-in-window: (+ (get deposits-in-window vault-data) u1),
            window-start: (get window-start vault-data)
        })
)

(define-private (check-rate-limit (vault-data (tuple (deposits-in-window uint) (window-start uint))))
    (if (> (- block-height (get window-start vault-data)) rate-limit-window)
        true
        (<= (get deposits-in-window vault-data) max-deposits-per-window))
)

;; Enhanced deposit function with rate limiting
(define-public (deposit (amount uint))
    (let (
        (current-vault (get-vault-or-default tx-sender))
        (new-balance (+ (get balance current-vault) amount))
        (new-total-deposits (+ (var-get total-deposits) amount))
        (rate-limit-data (update-rate-limit {
            deposits-in-window: (get deposits-in-window current-vault),
            window-start: (get window-start current-vault)
        }))
    )
    (asserts! (not (var-get contract-paused)) err-paused)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount max-deposit) err-deposit-limit)
    (asserts! (check-rate-limit rate-limit-data) err-rate-limit)
    
    (map-set user-vaults tx-sender {
        balance: new-balance,
        last-deposit: block-height,
        last-withdrawal: (get last-withdrawal current-vault),
        rewards-earned: (get rewards-earned current-vault),
        total-contributed: (+ (get total-contributed current-vault) amount),
        deposits-in-window: (get deposits-in-window rate-limit-data),
        window-start: (get window-start rate-limit-data),
        deposit-history: (unwrap-panic (as-max-len? 
            (concat (list amount) (get deposit-history current-vault))
            u10))
    })
    (var-set total-deposits new-total-deposits)
    (print {event: "deposit", user: tx-sender, amount: amount})
    (ok true))
)

;; Emergency withdrawal function for contract owner
(define-public (emergency-withdraw (user principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let ((current-vault (get-vault-or-default user)))
            (asserts! (<= amount (get balance current-vault)) err-insufficient-balance)
            (map-set user-vaults user
                (merge current-vault {
                    balance: (- (get balance current-vault) amount),
                    last-withdrawal: block-height
                })
            )
            (print {
                event: "emergency-withdrawal",
                user: user,
                amount: amount,
                initiated-by: contract-owner
            })
            (ok true))
    )
)

;; Additional getter functions
(define-read-only (get-user-deposit-history (user principal))
    (get deposit-history (get-vault-or-default user))
)

(define-read-only (get-user-rate-limit-status (user principal))
    (let ((vault (get-vault-or-default user)))
        {
            deposits-in-window: (get deposits-in-window vault),
            window-start: (get window-start vault),
            can-deposit: (check-rate-limit {
                deposits-in-window: (get deposits-in-window vault),
                window-start: (get window-start vault)
            })
        }
    )
)
