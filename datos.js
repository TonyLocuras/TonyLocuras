// =====================================================================
//  DATOS DE LA WEB DE TONYLOCURAS
//  Aquí se cambia TODO lo que sale en la web.
//
//  Reglas para no romper nada:
//   - Cambia solo lo que va entre comillas "..." y los números.
//   - No borres las comas , ni los corchetes [ ] ni las llaves { }.
//   - Los precios van con PUNTO, no con coma: 49.95 (no 49,95).
//   - Para quitar algo sin borrarlo: activa: false
//
//  Después de guardar en GitHub, la web se actualiza en 1-2 minutos.
// =====================================================================

const DATOS = {

  // ------------------------------------------------------------------
  //  PROMOCIONES  (salen arriba del todo, encima de tu nombre)
  //
  //  activa:   true = se ve · false = oculta
  //  etiqueta: texto pequeño rojo (ej: "BLACK FRIDAY", "REBAJAS")
  //  hasta:    último día que se ve, en formato "año-mes-día".
  //            Ese día a las 23:59 desaparece sola. Pon "" para que no caduque nunca.
  //            Si pones fecha, sale una cuenta atrás ("Quedan 3 días").
  //  boton / enlace: deja boton: "" si no quieres botón.
  //  extraEnPacks: % extra que se descuenta sobre el precio con tu código.
  //            Si es mayor que 0, cada pack enseña también el precio con la promo.
  //            Pon 0 si la promo no se suma a tu código.
  //
  //  Para añadir otra promo: copia un bloque desde { hasta }, pégalo
  //  justo debajo (con una coma entre los dos bloques) y cambia los textos.
  // ------------------------------------------------------------------
  promociones: [
    {
      activa: true,
      etiqueta: "BLACK FRIDAY",
      titulo: "20 % extra en Vitastrong",
      texto: "Se suma a mi código tonylocura. Aprovecha antes de que se acabe.",
      boton: "Aprovechar ahora",
      enlace: "https://vitastrong.es/es/",
      hasta: "2026-11-30",
      extraEnPacks: 20
    }
  ],

  // ------------------------------------------------------------------
  //  CABECERA
  // ------------------------------------------------------------------
  nombre: "TonyLocuras",
  descripcion: "¿Te gusta la aventura extrema? Este es tu canal.\nExploración de lugares siniestros, rutas a 100 metros bajo tierra y supervivencia real. Cero simulaciones.",

  // ------------------------------------------------------------------
  //  REDES  (el usuario va SIN la @)
  // ------------------------------------------------------------------
  youtube: {
    usuario: "tonylocuras",
    idCanal: "UCslMWw_GJ4_AoIBsMChcflA",
    texto: "Mis expediciones al límite, en crudo",
    boton: "Suscribirme"
  },
  instagram: {
    activa: true,
    usuario: "tonylocuras.oficial",
    texto: "Detrás de cámaras"
  },
  tiktok: {
    activa: true,
    usuario: "tonylocuras.oficial",
    texto: "Clips cortos"
  },

  // ------------------------------------------------------------------
  //  HAZTE MIEMBRO
  // ------------------------------------------------------------------
  miembros: {
    activa: true,
    titulo: "Hazte miembro del canal",
    texto: "Los miembros tienen muchas ventajas exclusivas y es la forma más directa de apoyar y mejorar nuestras próximas aventuras",
    boton: "Unirme al canal"
  },

  // ------------------------------------------------------------------
  //  VITASTRONG
  //  descuento: el % de tu código. Con él se calculan solos los precios de los packs.
  //  En el texto, {codigo} se cambia solo por tu código en negrita.
  // ------------------------------------------------------------------
  vitastrong: {
    codigo: "tonylocura",
    descuento: 10,
    texto: "Entra por mi enlace y escribe el código {codigo} al pagar.",
    boton: "Ir a Vitastrong",
    enlace: "https://vitastrong.es/es/"
  },

  // ------------------------------------------------------------------
  //  CARRITOS
  //
  //  Cada pestaña tiene grupos, y cada grupo tiene packs.
  //  Pack:
  //    nombre, incluye, enlace
  //    precio:      precio SIN descuento
  //    precioFinal: (opcional) precio con tu código si no cuadra el cálculo
  //                 automático por un céntimo. Si no lo pones, se calcula solo.
  //    activa: false  -> lo oculta sin borrarlo
  //
  //  Para añadir un pack: copia una línea { nombre: ... }, pégala debajo
  //  y cambia los datos. Fíjate en que haya una coma al final de cada pack.
  // ------------------------------------------------------------------
  carritosTitulo: "Mis carritos",
  carritosTexto: "Ya vienen montados. Ves qué lleva cada uno y el precio que te sale con mi código.",

  pestanas: [
    {
      nombre: "Mis packs",
      grupos: [
        {
          titulo: "Packs de expedición",
          packs: [
            { nombre: "Pack esencial", incluye: "creatina Creastrong, pre-workout (red berries), EAA Pro (red berries), Wheystrong Protein (chocolate), maltodextrina", precio: 153.95, enlace: "https://vitastrong.es/amb/pack-esencial" },
            { nombre: "Pack 100 metros bajo tierra", incluye: "pack concentración, colágeno, pre-workout (red berries)", precio: 129.97, enlace: "https://vitastrong.es/amb/pack-100-metros-bajo-tierra" },
            { nombre: "Pack supervivencia", incluye: "Carbo Gel 2:1, Carbo Gel 2:1 + cafeína, magnesio y potasio, EAA Pro (red berries), maltodextrina, creatina Creastrong, box de 12 barritas de chocolate blanco, Hydra Pro", precio: 198.92, enlace: "https://vitastrong.es/amb/pack-supervivencia" },
            { nombre: "Recuperación post expedición", incluye: "BCAA 8:1:1, creatina Creastrong, omega 3, Drainpure Night", precio: 78.96, enlace: "https://vitastrong.es/amb/recuperacion-post-expedicion" },
          ]
        }
      ]
    },
    {
      nombre: "Por objetivo",
      grupos: [
        {
          titulo: "Fuerza y gimnasio",
          packs: [
            { nombre: "Primer gym", incluye: "creatina Creastrong, multivitamin, Wheystrong Protein (chocolate)", precio: 83.97, enlace: "https://vitastrong.es/amb/primer-gym" },
            { nombre: "Volumen", incluye: "creatina Creastrong, harina de avena doble choco, mantequilla de cacahuete clásica, ganador de masa", precio: 76.96, enlace: "https://vitastrong.es/amb/volumen" },
            { nombre: "Definición", incluye: "Wheystrong Isolate (chocolate), L-carnitina, Drainpure, creatina Creastrong", precio: 128.96, enlace: "https://vitastrong.es/amb/definicion" },
            { nombre: "Culturismo", incluye: "Wheystrong Isolate (chocolate), Creastrong Pro Pack, ganador de masa, L-arginine, glutamina, BCAA 8:1:1", precio: 190.95, enlace: "https://vitastrong.es/amb/culturismo" },
            { nombre: "Calistenia", incluye: "creatina Creastrong, Wheystrong Protein (chocolate), harina de avena natural, mantequilla de cacahuete crujiente", precio: 86.96, enlace: "https://vitastrong.es/amb/calistenia" },
          ]
        },
        {
          titulo: "Resistencia y recuperación",
          packs: [
            { nombre: "Corredor", incluye: "complejo de magnesio, vitamin B complex, aminoácidos esenciales, creatina Creastrong, EAA Pro (red berries)", precio: 89.95, precioFinal: 80.95, enlace: "https://vitastrong.es/amb/corredor" },
            { nombre: "Trail", incluye: "maltodextrina, complejo de magnesio, box de 12 barritas de chocolate blanco, Carbo Gel 2:1 + cafeína, Carbo Gel 2:1, calcetines negros", precio: 150.94, enlace: "https://vitastrong.es/amb/trail" },
            { nombre: "Resistencia y cardio", incluye: "creatina Creastrong, maltodextrina, BCAA 2:1:1, L-carnitina, 3 pre-workout monodosis (red berries)", precio: 79.00, enlace: "https://vitastrong.es/amb/residencia-y-cardio" },
            { nombre: "Recuperación", incluye: "Wheystrong Protein (chocolate), creatina Creastrong, glutamina, EAA Pro (red berries), complejo de magnesio", precio: 134.95, precioFinal: 121.45, enlace: "https://vitastrong.es/amb/recuperacion" },
          ]
        },
        {
          titulo: "Bienestar",
          packs: [
            { nombre: "Salud articular", incluye: "glucosamine, colágeno marino, omega 3, complejo de magnesio", precio: 88.96, enlace: "https://vitastrong.es/amb/salud-articular" },
            { nombre: "Pelo, piel y uñas", incluye: "colágeno, vitamina C + zinc, vitamin B complex, omega 3", precio: 63.96, enlace: "https://vitastrong.es/amb/pelo-piel-y-unas" },
            { nombre: "Antiestrés", incluye: "Melatonin Gummies, complejo de magnesio, ZMA", precio: 49.97, enlace: "https://vitastrong.es/amb/antiestres" },
            { nombre: "Foco: estudio y oficina", incluye: "Brainbooster, vitamin B complex, omega 3, granola proteica choco", precio: 52.96, enlace: "https://vitastrong.es/amb/foco-estudio-oficina" },
            { nombre: "Salud +40", incluye: "Cholesterol complex, omega 3, coenzima Q10", precio: 64.97, enlace: "https://vitastrong.es/amb/salud40" },
          ]
        },
        {
          titulo: "Cocina y comida",
          packs: [
            { nombre: "Desayunos fit", incluye: "harina de avena Choco, pancake proteico sabor chocolate, crema proteica de avellana, Zero Drops vainilla", precio: 35.96, enlace: "https://vitastrong.es/amb/desayunos-fit" },
            { nombre: "Pastelería proteica", incluye: "harina de avena natural, crema proteica de avellana, 2 peanut butter powder, gofres proteicos vainilla, Topping Zero Caramel Milk, Zero Drops brownie", precio: 57.93, enlace: "https://vitastrong.es/amb/pasteleria-proteica" },
            { nombre: "Cocina salada", incluye: "harina de avena natural, BBQ Zero, Ketchup Zero, Red Mix Spices, Golden Spices", precio: 37.95, enlace: "https://vitastrong.es/amb/cocina-salada" },
            { nombre: "Antojos dulces", incluye: "granola proteica choco, granola proteica caramelo, crema proteica de chocolate negro, 2 mantequillas de cacahuete crujiente, Zero Drops chocolate", precio: 47.94, enlace: "https://vitastrong.es/amb/antojos-dulces" },
            { nombre: "Snack de sofá", incluye: "box de 12 barritas de chocolate blanco, crema proteica de pistacho", precio: 44.98, enlace: "https://vitastrong.es/amb/snack-de-sofa" },
            { nombre: "Desayunos en familia", incluye: "gofres proteicos vainilla, pancake proteico chocolate, harina de avena natural, copos de avena doble chocolate, Topping Zero Caramel Milk", precio: 49.95, enlace: "https://vitastrong.es/amb/desayunos-en-familia" },
          ]
        }
      ]
    }
  ],

  // ------------------------------------------------------------------
  //  TEXTO DEL FINAL
  // ------------------------------------------------------------------
  notaFinal: "Enlaces de afiliado: si compras con ellos, me ayudas a seguir grabando."
};
