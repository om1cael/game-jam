using UnityEngine;

public class ShipEndAnimation : MonoBehaviour
{
    public Animator animator;

    void Start()
    {
        animator = GetComponent<Animator>();
    }

    void OnEnable()
    {
        GameEvents.OnAllHordesDefeated += GoAway;
    }

    void OnDisable()
    {
        GameEvents.OnAllHordesDefeated -= GoAway;
    }

    void GoAway()
    {
        Debug.Log("go away");
        animator.SetTrigger("end");
    }

}
