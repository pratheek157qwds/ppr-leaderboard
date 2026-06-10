document.addEventListener('DOMContentLoaded', () => {
    const screen = document.getElementById('leaderboard-nui');
    const closeBtn = document.getElementById('close-button');
    const totalCirculationEl = document.getElementById('total-circulation');
    const listRowsContainer = document.getElementById('list-rows-container');

    function formatCurrency(amount) {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(amount);
    }

    function setupAvatar(imgElement, fallbackElement, avatarSrc) {
        if (!avatarSrc || avatarSrc.trim() === "" || avatarSrc === "null") {
            imgElement.style.display = 'none';
            fallbackElement.style.display = 'flex';
            return;
        }

        let src = avatarSrc;
        if (!src.startsWith('http') && !src.startsWith('data:image')) {
            src = 'data:image/png;base64,' + src;
        }

        imgElement.src = src;
        imgElement.style.display = 'none';
        fallbackElement.style.display = 'flex';

        imgElement.onload = () => {
            imgElement.style.display = 'block';
            fallbackElement.style.display = 'none';
        };

        imgElement.onerror = () => {
            imgElement.style.display = 'none';
            fallbackElement.style.display = 'flex';
        };
    }

    function closeUI() {
        screen.classList.remove('active');
        fetch(`https://${GetParentResourceName()}/close`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        }).catch(err => {
            console.log('Not in FiveM environment, closing locally.');
        });
    }

    closeBtn.addEventListener('click', closeUI);
    window.addEventListener('keyup', (e) => {
        if (e.key === 'Escape') {
            closeUI();
        }
    });

    function updateLeaderboard(players) {
        listRowsContainer.innerHTML = '';

        let totalCirculation = 0;
        players.forEach(p => {
            const cash = Number(p.cash) || 0;
            const bank = Number(p.bank) || 0;
            const savings = Number(p.savings) || 0;
            totalCirculation += (cash + bank + savings);
        });
        totalCirculationEl.textContent = formatCurrency(totalCirculation);

        const sortedPlayers = [...players].sort((a, b) => {
            const wealthA = (Number(a.cash) || 0) + (Number(a.bank) || 0) + (Number(a.savings) || 0);
            const wealthB = (Number(b.cash) || 0) + (Number(b.bank) || 0) + (Number(b.savings) || 0);
            return wealthB - wealthA;
        });

        for (let i = 1; i <= 3; i++) {
            const player = sortedPlayers[i - 1];
            const pedestal = document.getElementById(`podium-rank-${i}`);
            
            if (player) {
                pedestal.style.opacity = '1';
                pedestal.style.pointerEvents = 'auto';

                const cash = Number(player.cash) || 0;
                const bank = Number(player.bank) || 0;
                const savings = Number(player.savings) || 0;
                const totalWealth = cash + bank + savings;

                document.getElementById(`name-${i}`).textContent = player.name || 'Unknown';
                document.getElementById(`wealth-${i}`).textContent = formatCurrency(totalWealth);
                
                const imgEl = document.getElementById(`avatar-${i}`);
                const fallbackEl = imgEl.nextElementSibling;
                setupAvatar(imgEl, fallbackEl, player.avatar);

                const breakdownEl = document.getElementById(`breakdown-${i}`);
                breakdownEl.innerHTML = `
                    <span>Cash: ${formatCurrency(cash)}</span>
                    <span>Bank: ${formatCurrency(bank)}</span>
                    ${savings > 0 ? `<span>Savings: ${formatCurrency(savings)}</span>` : ''}
                `;
            } else {
                pedestal.style.opacity = '0.3';
                pedestal.style.pointerEvents = 'none';
                document.getElementById(`name-${i}`).textContent = 'Vacancy';
                document.getElementById(`wealth-${i}`).textContent = '$0';
                const imgEl = document.getElementById(`avatar-${i}`);
                const fallbackEl = imgEl.nextElementSibling;
                setupAvatar(imgEl, fallbackEl, '');
            }
        }

        const remainingPlayers = sortedPlayers.slice(3, 10);
        if (remainingPlayers.length === 0) {
            const emptyEl = document.createElement('div');
            emptyEl.className = 'loading-state';
            emptyEl.innerHTML = `
                <span class="material-icons-round">info</span>
                <p>No additional records found</p>
            `;
            listRowsContainer.appendChild(emptyEl);
            return;
        }

        remainingPlayers.forEach((player, index) => {
            const rank = index + 4;
            const cash = Number(player.cash) || 0;
            const bank = Number(player.bank) || 0;
            const savings = Number(player.savings) || 0;
            const totalWealth = cash + bank + savings;

            const row = document.createElement('div');
            row.className = 'leaderboard-row';
            row.innerHTML = `
                <div class="row-rank">${rank}</div>
                <div class="row-player-info">
                    <div class="row-avatar">
                        <img src="" alt="Avatar" style="display:none;">
                        <span class="avatar-fallback material-icons-round">person</span>
                    </div>
                    <span class="row-name">${player.name || 'Unknown'}</span>
                </div>
                <div class="row-wealth-container">
                    <span class="row-total-wealth">${formatCurrency(totalWealth)}</span>
                    <span class="row-mini-details">
                        C: ${formatCurrency(cash)} | B: ${formatCurrency(bank)} ${savings > 0 ? `| S: ${formatCurrency(savings)}` : ''}
                    </span>
                </div>
            `;

            const imgEl = row.querySelector('.row-avatar img');
            const fallbackEl = row.querySelector('.avatar-fallback');
            setupAvatar(imgEl, fallbackEl, player.avatar);

            listRowsContainer.appendChild(row);
        });
    }

    window.addEventListener('message', (event) => {
        const item = event.data;
        if (item.action === 'showLeaderboard') {
            if (item.serverTitle) {
                document.getElementById('server-title').textContent = item.serverTitle;
            }
            updateLeaderboard(item.players || []);
            screen.classList.add('active');
        } else if (item.action === 'hideLeaderboard') {
            screen.classList.remove('active');
        }
    });

    if (!window.invokeNative) {
        console.log('Loading mock leaderboard data for preview...');
        const mockPlayers = [
            { name: "Franklin Clinton", cash: 1200000, bank: 3200000, savings: 1000000, avatar: "https://lh3.googleusercontent.com/aida-public/AB6AXuAE6LBCCQNKQHqxCppG6evnHHCVKlFypiA4ZK8p90hSXc2ajIh0eCFqNn9vToctIE_6fjTRekioavnYEyLdwUGSys2W-L3UuTLvgjisQDf9UQMwKZuRPo1o99QNZqwOYy-d0aoycgBcRiQpD7ApfPSGMZM9KGCRh9HF4DQLnbnoLfeS1E8GKQ4Rf7awZroOJBbZS4UHz1k-KGsHjkyoTb4vdRjCF4zh6T73fNoETVAxc3TLmCHeF_Z6ozpm0AyrR3rID-NAN4A9_Ig" },
            { name: "Michael De Santa", cash: 800000, bank: 3500000, savings: 500000, avatar: "https://lh3.googleusercontent.com/aida-public/AB6AXuBei44EkwjikhzrDf1t74I-2fEgSLPqKb-lzSx9-0CkdOQ8lVDSpeAg1h2TOPxE-Iuo57JSV3xx_MIVARZ8qR8R_h2v5A_zJ3Qwc2qZWddbwOo70ZH9Chhet-QTZmx78yNFxGo8gqexH2M1QoQmyu-_sZJ26xJE-gc2PnpgaqJNJtReu2kiiPv9q3e1SAQwCXGTfEFQ5ST1OnYgtqkJagWn0LnRY-1-_Owk20yc8fOP_0uJF7C8P85gxyxo__U-TPeN-NqdooyAAo4" },
            { name: "Trevor Philips", cash: 1500000, bank: 2500000, savings: 200000, avatar: "https://lh3.googleusercontent.com/aida-public/AB6AXuDEfBxznamM9625k59yIxnCB_ErIdWv3lV6iL9Nh4vcReR_bEHtIVGWhQnil060wxXwxDGSFDv0KYZQuWucpTIxqJzbGiwNuQ3j8G8ElFhqAinQcLyj5_t5ZedEQA6DUDGhlqSgcwHDSrKE1YrVTtmMsjAQ_-MY3Ibf5N77Ks0pt-yxgdHOuDrKCCRWmmhrAsdbel7lVPuQWHoq5KL_1rmbNCs2uhr7TqaiCIoNWxNMQcLzvUbJ1N9-wcjq7FTXrVcspQdMGKs1Tl8" },
            { name: "Lester Crest", cash: 350000, bank: 3000000, savings: 500000, avatar: "https://lh3.googleusercontent.com/aida-public/AB6AXuD4PCoM2eKf8Qnlz8LSSQwEZPYY8ohQ65Q3HLKmzvt68TjkH0VL-UE-Bzq0R9poMzvcr8dBT5evIoXtYAOKH1aj2VCKjR0-rucXEDxr94317GOymxNXwIivEaOGGniIKpLgsPdUnw9pL53L2uuo-DvREMf6cpWkEgBz8f_po6bIbXIgnZ2Q-uZCMU5nj2CSFtkUXukpqre2r3rJIKm5U858YZJHRd-wF1ymsZKbCx0VIxXAMlh5GR2UNF6iMD6PVdKb1cIv8UxMGtY" },
            { name: "Amanda De Santa", cash: 120000, bank: 3000000, savings: 0, avatar: "https://lh3.googleusercontent.com/aida-public/AB6AXuAteAOnM10VtcHMw4w3L6A-IJuQrguk9psoFWAfHtZe66JCQxKA8DFYeGYsCar-gsBZ_8GXPZk4S4P-rpkr4jmyzy5-XUeg9JnfW6iOa6gMQxHzHW5-eWv6w2AcS3p4n6np6F6KM8IaSODzw4cE78oGfkyPHjnfgULbqAxotsFfGd5C5NygWCE2qBuiGqFSyZlKrY-w6w9dKI4QKmffpIqzN2csyHrltK84v1GeLnoFYj_-zGBzkg4aRGAB7AXX7yMHIgIn84B_Qk4" },
            { name: "Lamar Davis", cash: 50000, bank: 2900000, savings: 0, avatar: "https://lh3.googleusercontent.com/aida-public/AB6AXuA79OBwAP7TZo-0SuyFDZ1soQ5QktJx6bqUz1PxirlAIGo4g4ziHqL4TF4m3SZFGAHEj63Z7tw6bFYUFPs1oyirF_q8Tdgl6yWlXy-yyqpEI5oNes2LrQSWCjqdfmJYj4CeNnLECi6zPvo1oqqfnmCE-XXR7oHDMLPiiv1kjnyhxgSXZ9Bkl2h-ZeZRIUow6e6PMxW_6JXhJgIwsZbipcS-iM8nXumShaLQ69ma4tivLtq5x6eNGpOlLQIAfZiuqYDxbRs0Z6moC-8" },
            { name: "Martin Madrazo", cash: 250000, bank: 2000000, savings: 500000, avatar: "https://lh3.googleusercontent.com/aida-public/AB6AXuBArtoF_7_-wQnKC6lc0d7icDmp9_d9j9gDwOrUmBz-8teYB9Sgk0-zAERPtAKzk_WcqVadECpPgs_p5lQK857cQr-kiDpPUJ_yCqXfIX-RBe33NhXgbGnsbMOOrlG4gU3h1Vwnkg67CWQiuZT-dIITJtZQhjSgxLmP2bOrCy5QkRMQUPLr91LepIlV4U-GFO0jc3s8pYHsOawAAbfqT8zfjY6bZOzjnWVNlgj7Ra1rvfpyRtYxez-RWxzr4EYu8lY6m81wTHinePk" },
            { name: "Devin Weston", cash: 0, bank: 2400000, savings: 0, avatar: "https://lh3.googleusercontent.com/aida-public/AB6AXuCfzr3bcKHNm3p43c8NsQTQgMz6YOunu0-g5mGqfummHvfEMZDd0aDj4I7sQomNQrfT1-s-MqBu_YhGEUxA2rBFFeUwaFQfKU8fofhqHj3lOT_AbdS4sQWk9bRDbffHygbCUVjzDEhQn__hny6TVHjRHEK9cgRsI5YJJKfuNkBR7MOMwmoH429Vz1BBl_O2TgNZfGeTKG7i4V5zoVexgZ5HB1qrqZRC61BUrhCFfumhpIcl_opu5D4dW6H61pJwo5ebf6H37etxDIU" },
            { name: "Jimmy De Santa", cash: 15000, bank: 150000, savings: 0, avatar: "" }
        ];

        setTimeout(() => {
            updateLeaderboard(mockPlayers);
            screen.classList.add('active');
        }, 800);
    }
});
