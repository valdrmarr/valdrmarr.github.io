`use strict`;

(function () {

    const cropElement = document.querySelectorAll('.post-description'), // выбор элементов
          size = 200                                             // кол-во символов
          endCharacter = '......';                                  // окончание

    cropElement.forEach(el => {
        let text = el.innerHTML;

        if (el.innerHTML.length > size) {
            text = text.substr(0, size);
            el.innerHTML = text + endCharacter;
        }
    });

}());