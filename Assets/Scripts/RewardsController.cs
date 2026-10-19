using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class RewardsController : MonoBehaviour
{
    [SerializeField] private List<RewardSO> rewards;

    [Header("UI")]
    [SerializeField] private GameObject rewardPanel;
    [SerializeField] private TMP_Text rewardName;
    [SerializeField] private TMP_Text rewardDescription;
    [SerializeField] private Image rewardImage;
    [SerializeField] private Button closeButton;


    int currentReward = 0;

    void OnEnable()
    {
        GameEvents.OnHorderDefeated += ShowReward;
    }

    void OnDisable()
    {
        GameEvents.OnHorderDefeated -= ShowReward;
    }


    void ShowReward()
    {
        Time.timeScale = 0f;

        RewardSO reward = rewards[currentReward];

        rewardName.text = reward.rewardName;
        rewardDescription.text = reward.description;
        rewardImage.sprite = reward.rewardImage;

        rewardPanel.SetActive(true);
        currentReward++;

        closeButton.onClick.AddListener(() =>
        {
            rewardPanel.SetActive(false);
            Time.timeScale = 1f;
        });
    }
}
