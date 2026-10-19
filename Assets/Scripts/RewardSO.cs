using UnityEngine;
using UnityEngine.UI;

[CreateAssetMenu(fileName = "Reward", menuName = "ScriptableObjects/RewardScriptableObject", order = 1)]
public class RewardSO : ScriptableObject
{
    public Sprite rewardImage;
    public string rewardName;
    public string description;
}
