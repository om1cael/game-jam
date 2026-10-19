using UnityEngine;
using UnityEngine.InputSystem;

public class GunController : MonoBehaviour
{
    private Camera cam;
    [SerializeField] private GameObject projectile;
    [SerializeField] private Transform projectileSpawnPos;

    [SerializeField] private SpriteRenderer gunSprite;

    private InputSystem_Actions inputActions;

    void Awake()
    {
        inputActions = new InputSystem_Actions();
    }


    void Start()
    {
        cam = Camera.main;
    }

    void OnEnable()
    {
        inputActions.Player.Enable();
    }

    void OnDisable()
    {
        inputActions.Player.Disable();
    }

    void Update()
    {
        Shoot();
        Rotate();
    }

    void Shoot()
    {
        bool shootRequested = inputActions.Player.Attack.triggered;

        if (shootRequested)
        {
            Instantiate(projectile, projectileSpawnPos.position, Quaternion.identity);
        }
    }

    void Rotate()
    {
        Vector2 mouseScreenPos = Mouse.current.position.ReadValue();

        Vector3 mousePos = cam.ScreenToWorldPoint(new Vector3(
            mouseScreenPos.x,
            mouseScreenPos.y,
            Mathf.Abs(cam.transform.position.z - transform.position.z)
        ));


        Vector2 direction = mousePos - transform.position;
        float angle = Mathf.Atan2(direction.y, direction.x) * Mathf.Rad2Deg;

        transform.rotation = Quaternion.Euler(0f, 0f, angle);

        gunSprite.flipY = transform.eulerAngles.z >= 100;
    }
}