using UnityEngine;

public class NCController : MonoBehaviour
{
    public GameObject player;
    public float speed = 1.5f;

    // Update is called once per frame
    void Update()
    {
        transform.position = Vector2.MoveTowards(transform.position, new Vector2(player.transform.position.x + 1.0f, player.transform.position.y + 1.0f), speed * Time.deltaTime);
    }
}
