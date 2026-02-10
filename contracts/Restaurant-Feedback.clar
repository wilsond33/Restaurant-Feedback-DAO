;; title: Restaurant-Feedback
;; version:
;; summary:
;; description:



(define-non-fungible-token diner-pass uint)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-VOTING-ENDED (err u104))
(define-constant ERR-INVALID-PROPOSAL (err u105))
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))
(define-constant ERR-ACHIEVEMENT-NOT-FOUND (err u111))
(define-constant ERR-REWARD-ALREADY-CLAIMED (err u112))
(define-constant ERR-INSUFFICIENT-REWARD-POOL (err u113))
(define-constant ERR-MILESTONE-NOT-REACHED (err u114))
(define-constant ERR-COOLDOWN-ACTIVE (err u115))
(define-constant ERR-CANNOT-DELEGATE-TO-SELF (err u116))
(define-constant ERR-CIRCULAR-DELEGATION (err u117))
(define-constant ERR-NO-DELEGATION-FOUND (err u118))

(define-constant REWARD-POOL-BASE u1000000)
(define-constant ACHIEVEMENT-MULTIPLIER u2)
(define-constant MILESTONE-BONUS u500000)
(define-constant CLAIM-COOLDOWN u1440)

(define-data-var token-id-nonce uint u1)
(define-data-var proposal-id-nonce uint u1)
(define-data-var restaurant-name (string-ascii 64) "The Blockchain Bistro")
(define-data-var total-reward-pool uint u0)
(define-data-var next-achievement-id uint u1)

(define-map proposals
    uint
    {
        title: (string-ascii 128),
        description: (string-ascii 512),
        proposer: principal,
        yes-votes: uint,
        no-votes: uint,
        end-block: uint,
        executed: bool,
        proposal-type: (string-ascii 32)
    }
)

(define-map votes
    { proposal-id: uint, voter: principal }
    { vote: bool, voting-power: uint }
)

(define-map member-stats
    principal
    {
        total-votes: uint,
        successful-proposals: uint,
        reputation-score: uint,
        last-activity: uint
    }
)

(define-map perks-claimed
    { member: principal, perk-type: (string-ascii 32) }
    { claimed: bool, claim-block: uint }
)

(define-map achievements
    uint
    {
        name: (string-ascii 64),
        description: (string-ascii 256),
        reward-amount: uint,
        requirements: (string-ascii 128),
        achievement-type: (string-ascii 32),
        active: bool
    }
)

(define-map member-achievements
    { member: principal, achievement-id: uint }
    {
        unlocked: bool,
        unlock-block: uint,
        reward-claimed: bool,
        claim-block: uint
    }
)

(define-map milestone-progress
    principal
    {
        current-streak: uint,
        longest-streak: uint,
        total-engagement-score: uint,
        milestone-level: uint,
        last-activity-block: uint
    }
)

(define-map reward-claims
    { member: principal, claim-type: (string-ascii 32) }
    {
        last-claim-block: uint,
        total-claimed: uint,
        consecutive-claims: uint
    }
)

(define-map delegations
    principal
    {
        delegate: principal,
        delegation-block: uint,
        active: bool
    }
)

(define-map delegation-power
    principal
    { total-delegated-power: uint }
)

(define-read-only (get-achievement (achievement-id uint))
    (map-get? achievements achievement-id)
)

(define-read-only (get-member-achievement (member principal) (achievement-id uint))
    (map-get? member-achievements { member: member, achievement-id: achievement-id })
)

(define-read-only (get-milestone-progress (member principal))
    (default-to
        { current-streak: u0, longest-streak: u0, total-engagement-score: u0, milestone-level: u0, last-activity-block: u0 }
        (map-get? milestone-progress member)
    )
)

(define-read-only (get-claim-history (member principal) (claim-type (string-ascii 32)))
    (default-to
        { last-claim-block: u0, total-claimed: u0, consecutive-claims: u0 }
        (map-get? reward-claims { member: member, claim-type: claim-type })
    )
)

(define-read-only (get-total-reward-pool)
    (var-get total-reward-pool)
)

(define-read-only (check-achievement-eligibility (member principal) (achievement-id uint))
    (let 
        (
            (achievement-data (map-get? achievements achievement-id))
            (current-stats (get-member-stats member))
            (member-progress (get-milestone-progress member))
            (existing-achievement (map-get? member-achievements { member: member, achievement-id: achievement-id }))
        )
        (match achievement-data
            achievement
            (ok {
                eligible: (and 
                    (get active achievement)
                    (is-none existing-achievement)
                    (>= (get reputation-score current-stats) u25)
                ),
                current-reputation: (get reputation-score current-stats),
                current-engagement: (get total-engagement-score member-progress),
                achievement-active: (get active achievement)
            })
            (ok { eligible: false, current-reputation: u0, current-engagement: u0, achievement-active: false })
        )
    )
)

(define-read-only (get-member-reward-summary (member principal))
    (let 
        (
            (stats (get-member-stats member))
            (progress (get-milestone-progress member))
            (achievement-claims (get-claim-history member "achievement"))
            (milestone-claims (get-claim-history member "milestone"))
        )
        (ok {
            reputation-score: (get reputation-score stats),
            current-milestone-level: (get milestone-level progress),
            current-streak: (get current-streak progress),
            total-engagement: (get total-engagement-score progress),
            achievements-claimed: (get total-claimed achievement-claims),
            milestones-claimed: (get total-claimed milestone-claims),
            next-milestone-requirement: (* (+ (get milestone-level progress) u1) u25)
        })
    )
)

(define-read-only (get-leaderboard-stats (member principal))
    (let 
        (
            (stats (get-member-stats member))
            (progress (get-milestone-progress member))
        )
        (ok {
            member: member,
            reputation-score: (get reputation-score stats),
            total-votes: (get total-votes stats),
            successful-proposals: (get successful-proposals stats),
            milestone-level: (get milestone-level progress),
            engagement-score: (get total-engagement-score progress),
            longest-streak: (get longest-streak progress)
        })
    )
)

(define-read-only (get-last-token-id)
    (ok (- (var-get token-id-nonce) u1))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? diner-pass token-id))
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-member-stats (member principal))
    (default-to
        { total-votes: u0, successful-proposals: u0, reputation-score: u0, last-activity: u0 }
        (map-get? member-stats member)
    )
)

(define-read-only (get-voting-power (member principal))
    (let ((stats (get-member-stats member)))
        (+ u1 (/ (get reputation-score stats) u10))
    )
)

(define-read-only (get-total-voting-power (member principal))
    (let 
        (
            (base-power (get-voting-power member))
            (delegated-power (default-to { total-delegated-power: u0 } (map-get? delegation-power member)))
        )
        (+ base-power (get total-delegated-power delegated-power))
    )
)

(define-read-only (get-delegation (member principal))
    (map-get? delegations member)
)

(define-read-only (get-delegation-power-total (delegate principal))
    (default-to { total-delegated-power: u0 } (map-get? delegation-power delegate))
)

(define-read-only (is-eligible-for-perk (member principal) (perk-type (string-ascii 32)))
    (let ((stats (get-member-stats member)))
        (and
            (>= (get reputation-score stats) u50)
            (>= (get total-votes stats) u5)
            (is-none (map-get? perks-claimed { member: member, perk-type: perk-type }))
        )
    )
)

(define-read-only (get-restaurant-name)
    (var-get restaurant-name)
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-TOKEN-OWNER)
        (nft-transfer? diner-pass token-id sender recipient)
    )
)

(define-public (mint-diner-pass (recipient principal))
    (let ((token-id (var-get token-id-nonce)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (try! (nft-mint? diner-pass token-id recipient))
        (var-set token-id-nonce (+ token-id u1))
        (ok token-id)
    )
)

(define-public (create-proposal
    (title (string-ascii 128))
    (description (string-ascii 512))
    (proposal-type (string-ascii 32))
    (voting-period uint)
)
    (let 
        (
            (proposal-id (var-get proposal-id-nonce))
            (end-block (+ stacks-block-height voting-period))
        )
        (asserts! (> (len title) u0) ERR-INVALID-PROPOSAL)
        (asserts! (> (len description) u0) ERR-INVALID-PROPOSAL)
        (asserts! (> voting-period u0) ERR-INVALID-PROPOSAL)
        (asserts! (is-some (nft-get-owner? diner-pass u1)) (err u107))
        
        (map-set proposals proposal-id
            {
                title: title,
                description: description,
                proposer: tx-sender,
                yes-votes: u0,
                no-votes: u0,
                end-block: end-block,
                executed: false,
                proposal-type: proposal-type
            }
        )
        
        (var-set proposal-id-nonce (+ proposal-id u1))
        (update-member-activity tx-sender)
        (ok proposal-id)
    )
)

(define-public (vote (proposal-id uint) (support bool))
    (let 
        (
            (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
            (total-power (get-total-voting-power tx-sender))
            (current-block stacks-block-height)
        )
        (asserts! (<= current-block (get end-block proposal)) ERR-VOTING-ENDED)
        (asserts! (is-none (map-get? votes { proposal-id: proposal-id, voter: tx-sender })) ERR-ALREADY-VOTED)
        (asserts! (is-some (nft-get-owner? diner-pass u1)) (err u107))
        
        (map-set votes
            { proposal-id: proposal-id, voter: tx-sender }
            { vote: support, voting-power: total-power }
        )
        
        (if support
            (map-set proposals proposal-id
                (merge proposal { yes-votes: (+ (get yes-votes proposal) total-power) })
            )
            (map-set proposals proposal-id
                (merge proposal { no-votes: (+ (get no-votes proposal) total-power) })
            )
        )
        
        (update-member-voting-stats tx-sender)
        (update-member-engagement tx-sender)
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND)))
        (asserts! (>= stacks-block-height (get end-block proposal)) ERR-VOTING-ENDED)
        (asserts! (not (get executed proposal)) (err u108))
        (asserts! (> (get yes-votes proposal) (get no-votes proposal)) (err u109))
        
        (map-set proposals proposal-id
            (merge proposal { executed: true })
        )
        
        (update-proposer-success (get proposer proposal))
        (ok true)
    )
)

(define-public (claim-perk (perk-type (string-ascii 32)))
    (let ((current-block stacks-block-height))
        (asserts! (is-eligible-for-perk tx-sender perk-type) (err u110))
        
        (map-set perks-claimed
            { member: tx-sender, perk-type: perk-type }
            { claimed: true, claim-block: current-block }
        )
        
        (ok true)
    )
)

(define-public (update-restaurant-name (new-name (string-ascii 64)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (var-set restaurant-name new-name)
        (ok true)
    )
)

(define-public (create-achievement
    (name (string-ascii 64))
    (description (string-ascii 256))
    (reward-amount uint)
    (requirements (string-ascii 128))
    (achievement-type (string-ascii 32))
)
    (let ((achievement-id (var-get next-achievement-id)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (> (len name) u0) ERR-INVALID-PROPOSAL)
        (asserts! (> reward-amount u0) ERR-INVALID-PROPOSAL)
        
        (map-set achievements achievement-id
            {
                name: name,
                description: description,
                reward-amount: reward-amount,
                requirements: requirements,
                achievement-type: achievement-type,
                active: true
            }
        )
        
        (var-set next-achievement-id (+ achievement-id u1))
        (ok achievement-id)
    )
)

(define-public (unlock-achievement (member principal) (achievement-id uint))
    (let 
        (
            (achievement-data (unwrap! (map-get? achievements achievement-id) ERR-ACHIEVEMENT-NOT-FOUND))
            (member-progress (get-milestone-progress member))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (asserts! (get active achievement-data) ERR-ACHIEVEMENT-NOT-FOUND)
        (asserts! (is-none (map-get? member-achievements { member: member, achievement-id: achievement-id })) ERR-REWARD-ALREADY-CLAIMED)
        
        (map-set member-achievements
            { member: member, achievement-id: achievement-id }
            {
                unlocked: true,
                unlock-block: stacks-block-height,
                reward-claimed: false,
                claim-block: u0
            }
        )
        
        (update-member-engagement member)
        (ok true)
    )
)

(define-public (claim-achievement-reward (achievement-id uint))
    (let 
        (
            (achievement-data (unwrap! (map-get? achievements achievement-id) ERR-ACHIEVEMENT-NOT-FOUND))
            (member-achievement (unwrap! (map-get? member-achievements { member: tx-sender, achievement-id: achievement-id }) ERR-ACHIEVEMENT-NOT-FOUND))
            (reward-amount (get reward-amount achievement-data))
        )
        (asserts! (get unlocked member-achievement) ERR-ACHIEVEMENT-NOT-FOUND)
        (asserts! (not (get reward-claimed member-achievement)) ERR-REWARD-ALREADY-CLAIMED)
        (asserts! (>= (var-get total-reward-pool) reward-amount) ERR-INSUFFICIENT-REWARD-POOL)
        
        (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
        
        (map-set member-achievements
            { member: tx-sender, achievement-id: achievement-id }
            (merge member-achievement { reward-claimed: true, claim-block: stacks-block-height })
        )
        
        (var-set total-reward-pool (- (var-get total-reward-pool) reward-amount))
        (update-claim-history tx-sender "achievement")
        (ok reward-amount)
    )
)

(define-public (claim-milestone-reward (milestone-level uint))
    (let 
        (
            (member-progress (get-milestone-progress tx-sender))
            (reward-amount (* MILESTONE-BONUS milestone-level))
            (last-claim (get-claim-history tx-sender "milestone"))
        )
        (asserts! (>= (get milestone-level member-progress) milestone-level) ERR-MILESTONE-NOT-REACHED)
        (asserts! (>= (- stacks-block-height (get last-claim-block last-claim)) CLAIM-COOLDOWN) ERR-COOLDOWN-ACTIVE)
        (asserts! (>= (var-get total-reward-pool) reward-amount) ERR-INSUFFICIENT-REWARD-POOL)
        
        (try! (as-contract (stx-transfer? reward-amount tx-sender tx-sender)))
        
        (var-set total-reward-pool (- (var-get total-reward-pool) reward-amount))
        (update-claim-history tx-sender "milestone")
        (ok reward-amount)
    )
)

(define-public (fund-reward-pool (amount uint))
    (begin
        (asserts! (> amount u0) ERR-INVALID-PROPOSAL)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set total-reward-pool (+ (var-get total-reward-pool) amount))
        (ok true)
    )
)

(define-public (calculate-engagement-bonus (member principal))
    (let 
        (
            (stats (get-member-stats member))
            (progress (get-milestone-progress member))
            (base-bonus (* (get reputation-score stats) u100))
            (streak-bonus (* (get current-streak progress) u50))
            (milestone-bonus (* (get milestone-level progress) MILESTONE-BONUS))
        )
        (ok (+ base-bonus (+ streak-bonus milestone-bonus)))
    )
)

(define-public (delegate-voting-power (delegate principal))
    (let 
        (
            (delegator-power (get-voting-power tx-sender))
            (current-delegation (map-get? delegations tx-sender))
            (current-block stacks-block-height)
        )
        (asserts! (not (is-eq tx-sender delegate)) ERR-CANNOT-DELEGATE-TO-SELF)
        (asserts! (is-none (map-get? delegations delegate)) ERR-CIRCULAR-DELEGATION)
        (asserts! (is-some (nft-get-owner? diner-pass u1)) (err u107))
        
        (match current-delegation
            existing-delegation
            (let 
                (
                    (old-delegate (get delegate existing-delegation))
                    (old-delegate-power (default-to { total-delegated-power: u0 } (map-get? delegation-power old-delegate)))
                )
                (map-set delegation-power old-delegate
                    { total-delegated-power: (- (get total-delegated-power old-delegate-power) delegator-power) }
                )
            )
            true
        )
        
        (let 
            (
                (delegate-power-record (default-to { total-delegated-power: u0 } (map-get? delegation-power delegate)))
            )
            (map-set delegation-power delegate
                { total-delegated-power: (+ (get total-delegated-power delegate-power-record) delegator-power) }
            )
        )
        
        (map-set delegations tx-sender
            {
                delegate: delegate,
                delegation-block: current-block,
                active: true
            }
        )
        
        (ok true)
    )
)

(define-public (revoke-delegation)
    (let 
        (
            (delegation-record (unwrap! (map-get? delegations tx-sender) ERR-NO-DELEGATION-FOUND))
            (delegate (get delegate delegation-record))
            (delegator-power (get-voting-power tx-sender))
            (delegate-power-record (default-to { total-delegated-power: u0 } (map-get? delegation-power delegate)))
        )
        (asserts! (get active delegation-record) ERR-NO-DELEGATION-FOUND)
        
        (map-set delegation-power delegate
            { total-delegated-power: (- (get total-delegated-power delegate-power-record) delegator-power) }
        )
        
        (map-set delegations tx-sender
            (merge delegation-record { active: false })
        )
        
        (ok true)
    )
)

(define-private (update-member-engagement (member principal))
    (let 
        (
            (current-progress (get-milestone-progress member))
            (current-block stacks-block-height)
            (last-activity (get last-activity-block current-progress))
            (block-diff (- current-block last-activity))
        )
        (if (<= block-diff u1440)
            (map-set milestone-progress member
                (merge current-progress 
                    {
                        current-streak: (+ (get current-streak current-progress) u1),
                        total-engagement-score: (+ (get total-engagement-score current-progress) u10),
                        milestone-level: (calculate-milestone-level (+ (get total-engagement-score current-progress) u10)),
                        last-activity-block: current-block
                    }
                )
            )
            (map-set milestone-progress member
                (merge current-progress 
                    {
                        current-streak: u1,
                        total-engagement-score: (+ (get total-engagement-score current-progress) u5),
                        milestone-level: (calculate-milestone-level (+ (get total-engagement-score current-progress) u5)),
                        last-activity-block: current-block
                    }
                )
            )
        )
    )
)

(define-private (update-claim-history (member principal) (claim-type (string-ascii 32)))
    (let 
        (
            (current-claims (get-claim-history member claim-type))
            (current-block stacks-block-height)
        )
        (map-set reward-claims
            { member: member, claim-type: claim-type }
            {
                last-claim-block: current-block,
                total-claimed: (+ (get total-claimed current-claims) u1),
                consecutive-claims: (+ (get consecutive-claims current-claims) u1)
            }
        )
    )
)

(define-private (calculate-milestone-level (engagement-score uint))
    (if (>= engagement-score u500) u10
        (if (>= engagement-score u400) u9
            (if (>= engagement-score u300) u8
                (if (>= engagement-score u250) u7
                    (if (>= engagement-score u200) u6
                        (if (>= engagement-score u150) u5
                            (if (>= engagement-score u100) u4
                                (if (>= engagement-score u75) u3
                                    (if (>= engagement-score u50) u2
                                        (if (>= engagement-score u25) u1 u0)
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

(define-private (update-member-activity (member principal))
    (let 
        (
            (current-stats (get-member-stats member))
            (current-block stacks-block-height)
        )
        (map-set member-stats member
            (merge current-stats { last-activity: current-block })
        )
    )
)

(define-private (update-member-voting-stats (member principal))
    (let ((current-stats (get-member-stats member)))
        (map-set member-stats member
            (merge current-stats 
                { 
                    total-votes: (+ (get total-votes current-stats) u1),
                    reputation-score: (+ (get reputation-score current-stats) u5),
                    last-activity: stacks-block-height
                }
            )
        )
    )
)

(define-private (update-proposer-success (proposer principal))
    (let ((current-stats (get-member-stats proposer)))
        (map-set member-stats proposer
            (merge current-stats 
                { 
                    successful-proposals: (+ (get successful-proposals current-stats) u1),
                    reputation-score: (+ (get reputation-score current-stats) u20)
                }
            )
        )
    )
)

(define-public (batch-mint-passes (recipients (list 50 principal)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (ok (map mint-single-pass recipients))
    )
)

(define-private (mint-single-pass (recipient principal))
    (let ((token-id (var-get token-id-nonce)))
        (match (nft-mint? diner-pass token-id recipient)
            success (begin
                (var-set token-id-nonce (+ token-id u1))
                token-id
            )
            error u0
        )
    )
)

(define-read-only (get-proposal-results (proposal-id uint))
    (match (map-get? proposals proposal-id)
        proposal (ok {
            title: (get title proposal),
            yes-votes: (get yes-votes proposal),
            no-votes: (get no-votes proposal),
            total-votes: (+ (get yes-votes proposal) (get no-votes proposal)),
            passed: (> (get yes-votes proposal) (get no-votes proposal)),
            executed: (get executed proposal)
        })
        ERR-PROPOSAL-NOT-FOUND
    )
)

(define-read-only (get-active-proposals)
    (ok "Use off-chain indexing to get active proposals")
)

(define-read-only (get-member-perks (member principal))
    (let ((stats (get-member-stats member)))
        (ok {
            reputation-score: (get reputation-score stats),
            total-votes: (get total-votes stats),
            successful-proposals: (get successful-proposals stats),
            voting-power: (get-voting-power member)
        })
    )
)

(define-constant ERR-INVALID-RATING (err u119))
(define-constant ERR-REVIEW-NOT-FOUND (err u120))
(define-constant ERR-ALREADY-REVIEWED (err u121))
(define-constant ERR-CANNOT-UPVOTE-OWN (err u122))
(define-constant ERR-ALREADY-UPVOTED (err u123))

(define-data-var review-id-nonce uint u1)

(define-map reviews
    uint
    {
        reviewer: principal,
        rating: uint,
        title: (string-ascii 64),
        content: (string-ascii 256),
        category: (string-ascii 32),
        block-submitted: uint,
        upvote-count: uint,
        flagged: bool
    }
)

(define-map reviewer-history
    principal
    {
        review-count: uint,
        total-rating-given: uint,
        upvotes-received: uint,
        last-review-block: uint
    }
)

(define-map review-upvotes
    { review-id: uint, voter: principal }
    { upvoted: bool }
)

(define-map restaurant-rating-summary
    (string-ascii 32)
    {
        total-reviews: uint,
        total-rating: uint,
        highest-rating: uint,
        lowest-rating: uint
    }
)

(define-read-only (get-review (review-id uint))
    (map-get? reviews review-id)
)

(define-read-only (get-reviewer-profile (reviewer principal))
    (default-to
        { review-count: u0, total-rating-given: u0, upvotes-received: u0, last-review-block: u0 }
        (map-get? reviewer-history reviewer)
    )
)

(define-read-only (get-category-summary (category (string-ascii 32)))
    (default-to
        { total-reviews: u0, total-rating: u0, highest-rating: u0, lowest-rating: u5 }
        (map-get? restaurant-rating-summary category)
    )
)

(define-read-only (get-average-category-rating (category (string-ascii 32)))
    (let ((summary (get-category-summary category)))
        (if (> (get total-reviews summary) u0)
            (ok (/ (get total-rating summary) (get total-reviews summary)))
            (ok u0)
        )
    )
)

(define-read-only (get-last-review-id)
    (ok (- (var-get review-id-nonce) u1))
)

(define-public (submit-review
    (rating uint)
    (title (string-ascii 64))
    (content (string-ascii 256))
    (category (string-ascii 32))
)
    (let 
        (
            (review-id (var-get review-id-nonce))
            (current-block stacks-block-height)
            (reviewer-data (get-reviewer-profile tx-sender))
            (category-data (get-category-summary category))
        )
        (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
        (asserts! (> (len title) u0) ERR-INVALID-PROPOSAL)
        (asserts! (> (len content) u0) ERR-INVALID-PROPOSAL)
        (asserts! (> (len category) u0) ERR-INVALID-PROPOSAL)

        (map-set reviews review-id
            {
                reviewer: tx-sender,
                rating: rating,
                title: title,
                content: content,
                category: category,
                block-submitted: current-block,
                upvote-count: u0,
                flagged: false
            }
        )

        (map-set reviewer-history tx-sender
            {
                review-count: (+ (get review-count reviewer-data) u1),
                total-rating-given: (+ (get total-rating-given reviewer-data) rating),
                upvotes-received: (get upvotes-received reviewer-data),
                last-review-block: current-block
            }
        )

        (map-set restaurant-rating-summary category
            {
                total-reviews: (+ (get total-reviews category-data) u1),
                total-rating: (+ (get total-rating category-data) rating),
                highest-rating: (if (> rating (get highest-rating category-data)) rating (get highest-rating category-data)),
                lowest-rating: (if (< rating (get lowest-rating category-data)) rating (get lowest-rating category-data))
            }
        )

        (var-set review-id-nonce (+ review-id u1))
        (update-member-engagement tx-sender)
        (ok review-id)
    )
)

(define-public (upvote-review (review-id uint))
    (let 
        (
            (review-data (unwrap! (map-get? reviews review-id) ERR-REVIEW-NOT-FOUND))
            (reviewer (get reviewer review-data))
            (reviewer-data (get-reviewer-profile reviewer))
        )
        (asserts! (not (is-eq tx-sender reviewer)) ERR-CANNOT-UPVOTE-OWN)
        (asserts! (is-none (map-get? review-upvotes { review-id: review-id, voter: tx-sender })) ERR-ALREADY-UPVOTED)

        (map-set review-upvotes
            { review-id: review-id, voter: tx-sender }
            { upvoted: true }
        )

        (map-set reviews review-id
            (merge review-data { upvote-count: (+ (get upvote-count review-data) u1) })
        )

        (map-set reviewer-history reviewer
            (merge reviewer-data { upvotes-received: (+ (get upvotes-received reviewer-data) u1) })
        )

        (ok true)
    )
)

(define-public (flag-review (review-id uint))
    (let 
        (
            (review-data (unwrap! (map-get? reviews review-id) ERR-REVIEW-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
        (map-set reviews review-id
            (merge review-data { flagged: true })
        )
        (ok true)
    )
)
