
//Конечная цель смарт-контракта будет в том, чтобы добавить и хранить записи о машине в реестр автомобилей в автосервисе, где владельцы машин могут отслеживать статус ремонта и оплачивать его. 
//Для этого нужно создать контракт, который будет принимать данные о машине и добавлять их в реестр, хранить владельца машины, дату записи в автосервис, описание ремонта и оплата ремонта

// SPDX-License-Identifier: GPL-3.0

// Объявление контракта
pragma solidity ^0.8.0;

//["mazda","3",2005, 1145456] - данные о машине
//[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] - аккаунт другого владельца
//[1709290800] дата записи в автосерсис в будущем
//[1646132400] дата записи в автосерсис в прошлом
//[Тех. обслуживние (гаранийное), 0] - описание ремонта и его цена
//[Замена тормозных колодок, 10] - описание ремонта и его цена


contract CarRegistration {
    // Структура для хранения информации о машине
    struct Car {
        string make; //марка автомобиля
        string model; //модель
        uint256 year; //год выпуска
        string vin; //вин авто
        address owner; //владелец
        uint256 serviceDate; // Unix timestamp of the scheduled service date
    }

     //структура для хранения информации о ремонте
    struct Repair {
        string description; //описание ремонта
        uint256 cost; //стоимость ремонта в wei
        bool paid; //флаг, указывающий, был ли счет оплачен
    }
    
    
    //массив для хранения информации о ремонтах
    Repair[] public repairs;
    
    //адрес, на который будут поступать платежи
    address payable public serviceAddress;

    // Хранилище зарегистрированных машин
    mapping (address => Car) public registeredCars;

    // Функция для регистрации машины
    function registerCar(string memory _make, string memory _model, uint256 _year, string memory _vin) public {
        // Проверяем, что машина еще не зарегистрирована
        require(registeredCars[msg.sender].owner == address(0), "Car is already registered");
        
        // Создаем новую запись о машине
        Car memory newCar = Car({
            make: _make,
            model: _model,
            year: _year,
            vin: _vin,
            owner: msg.sender,
            serviceDate: 0 

        });
        
        // Добавляем запись о машине в реестр
        registeredCars[msg.sender] = newCar;
    }

    // Функция для передачи владельца машины (если он сменился после последней записи в автосервисе)
    function transferOwnership(address _newOwner) public {
        // Получаем информацию о машине
        Car memory car = registeredCars[msg.sender];
        
        // Проверяем, что вызывающий контракт адрес совпадает с текущим владельцем машины
        require(msg.sender == car.owner, "You are not the owner of the car");
        
        // Обновляем запись о владельце машины
        car.owner = _newOwner;
        
        // Добавляем обновленную запись о машине в реестр
        registeredCars[_newOwner] = car;
    }
    // запись в автосервис
    function bookServiceOnDate(uint256 _serviceDate) public {
        Car memory car = registeredCars[msg.sender];
        require(_serviceDate > block.timestamp, "Service date cannot be in the past");
        car.serviceDate = _serviceDate;
    }
    //функция для получения даты записи
    function getServiceOnDate() public view returns (uint256) {
        Car memory car = registeredCars[msg.sender];
        return car.serviceDate;
    }
    //В этом контракте есть структура Repair для хранения информации о ремонтах, массив repairs для хранения всех ремонтов
    //событие, которое будет вызвано при добавлении нового ремонта
    event NewRepair(uint256 repairId, string description, uint256 cost);
    
    //событие, которое будет вызвано при оплате счета за ремонт
    event RepairPaid(uint256 repairId);
    
    //конструктор контракта
    constructor(address payable _serviceAddress) {
        serviceAddress = _serviceAddress;
    }
    
    //функция для добавления нового ремонта
    function addRepair(string memory _description, uint256 _cost) public {
        repairs.push(Repair({
            description: _description,
            cost: _cost,
            paid: false
        }));
        
        emit NewRepair(repairs.length - 1, _description, _cost);
    }
    
    //функция для получения количества ремонтов
    function getRepairsCount() public view returns (uint256) {
        return repairs.length;
    }
    
    //функция для оплаты счета за ремонт (не удалось оплатить, так как нет ETH на счету, но успешно проходит, если за ремонт 0 (гарантийное обслуживание))
    function payRepair(uint256 _repairId) public payable {
        require(_repairId < repairs.length, "Invalid repair ID");
        require(msg.value == repairs[_repairId].cost, "Incorrect payment amount");
        require(!repairs[_repairId].paid, "This repair has already been paid");
        
        //отправляем оплату на адрес автосервиса
        serviceAddress.transfer(msg.value);
        
        //устанавливаем флаг оплаты для ремонта
        repairs[_repairId].paid = true;
        
        emit RepairPaid(_repairId);
    }

}
