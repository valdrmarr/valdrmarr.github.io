function tedeevSVG() {
    const target = document.querySelector('.navbar-brand')

    target.innerHTML = ''
    target.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 172.02 32.18" className="">\n' +
        '    <style>.st1{fill:#5918df}</style>\n' +
        '    <text x="14" y="32" font-family="Roboto Condensed" font-size="42" fill="#f9f9f9" font-weight="700">TEDEEV</text>\n' +
        '    <path fill="#5918DF"\n' +
        '          d="M3.5 18.21l5.73-5.73-1.73-1.77-7.5 7.5 7.5 7.5 1.73-1.76-5.73-5.74zM145.46 27.82l2.26 1.11 11.22-22.59-2.26-1.11-11.22 22.59zM162.78 23.95l1.74 1.76 7.5-7.5-7.5-7.5-1.74 1.77 5.74 5.73-5.74 5.74z"\n' +
        '          className="st1"></path>\n' +
        '</svg>'
}

window.addEventListener('load', tedeevSVG)

function changeLinks() {
    const mySites = [
        'https://valdrmarr.github.io/3d-scroll-website/',
        'https://valdrmarr.github.io/3D-Parallax-Website-in-JavaScript-main/',
        'https://valdrmarr.github.io/parallax-scrolling-website/',
        'https://valdrmarr.github.io/3d-tilt-animation/',
        'https://valdrmarr.github.io/parallax-3d-lens-effect-website/',
        'https://valdrmarr.github.io/creative-scroll-website/',
        'https://valdrmarr.github.io/like-sportu/',
        'https://valdrmarr.github.io/MNTN-Landing/',
        'https://valdrmarr.github.io/floating-image/',
        'https://valdrmarr.github.io/3D-CSS-Parallax-Depth-Effect/',
        '#',
        'https://valdrmarr.github.io/horizontal-parallax-scrolling/',
        'https://valdrmarr.github.io/amazing-scroll-portfolio/',
        'https://valdrmarr.github.io/draggable-gallery/',
    ]

    function openSite(index) {
        let a = document.createElement('a')
        a.href = mySites[index]
        a.target = '_blank'
        setTimeout(() => {
            a.click()
        },800)
    }

    const linksFromDOM = document.querySelectorAll('#web > div > div > div')
    linksFromDOM.forEach((link, index) => {
        link.addEventListener('click', () => openSite(index))
    })
}

window.addEventListener('load', changeLinks)













